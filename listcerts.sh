#! /bin/sh
#
# Requirements: sh, awk, openssl
#
# Copyright 2023 David Groep, Nikhef, Amsterdam
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

nameformat=compat

usage() {
cat <<EOF

Usage: $0 [-h] [-n nameopt] certfile ...

  -h            show this help
  -n            nameformat: compat, oneline, RFC2253
                defaults to compat

Nameopt:
See also https://www.openssl.org/docs/man3.0/man1/openssl-namedisplay-options.html

EOF
  exit 1;
}


while getopts "hAn:" o
do
  case "${o}" in
    #A ) pkgmngr=apt ;;
    n ) nameformat=${OPTARG} ;;
    h ) usage ;;
  esac
done
shift $((OPTIND-1))

echo Processing files "$@"

awk '
    BEGIN { 
        incert=0; blob=0; 
        nameopt = "-nameopt '$nameformat'"
    }

    /-----BEGIN CERTIFICATE-----/ && incert {
        print "Error: invalid PEM file format in " FILENAME ":" FNR;
        exit 1;
    }

    /-----BEGIN CERTIFICATE-----/ && ! incert {
        pemdata  = $0 "\n";
        incert   = 1;
        pemlines = 1;
        blob     += 1;
        while ( incert ) {
            getline line;
            pemdata=pemdata line "\n";
            pemlines += 1;
            if ( pemlines > 256 ) {
                print "Error: invalid PEM file " FILENAME ": single blob too large (at " FNR ")";
                exit 1;
            }
            if ( line == "-----END CERTIFICATE-----" ) {
                print "---\nPEM blob " blob " with " pemlines " lines in " FILENAME ":";
                print pemdata | "openssl x509 -noout " nameopt " -issuer -subject -serial -startdate -enddate -fingerprint 2>&1 | sed -e s/^/\\ \\ /"
                close("openssl x509 -noout " nameopt " -issuer -subject -serial -startdate -enddate -fingerprint 2>&1 | sed -e s/^/\\ \\ /");
                incert = 0;
            }
        }
    }

    ' "$@"

