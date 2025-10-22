-----------------------------------------------------------------------------
TCStools - TCS Generation 5 (2025 edition)
-----------------------------------------------------------------------------

About
-----
The "tcsg5" scripts are for use with the 5th generation GEANT TCS service,
using HARICA as the back-end provider. Scripts for previous TCS generations
are still available on Github.
We apologize for the rather haphazard code layout, which is most certainly
'hackish' and originated as demonstrators or local scripts. We encourage
everyone to make improvements or do code cleanup.  The shell scripts are
written so as to require minimal dependencies (usually only OpenSSL and
basic utilities like ls, awk, or grep)

Some additional utility scripts useful for inspecting and debugging
certificate issues are included:
- probcert: connect to an SSL server or read a certificate or key file
  and display key attributes of the certificate found (expiry, SANs, modulus)
- listcerts.sh: list subject and issuer of all the PEM blobs in a file
- nik-acme-client: example of a ACME EAB client with resilience support,
  built on certbot but able to use HARICA as well as other ACME provides.
  For historical reasons, its default path suggests tcsg4, but it is generic.


-----------------------------------------------------------------------------
tcsg5-apitool - HARICA API for TCS Gen5
-----------------------------------------------------------------------------

Usage: tcsg5-apitool [-s andOTPfile.json] [-e endpoint] [-t tokenname]
    [-P passwordfile] [-U user_email] [-R csrfile_pem] [-h] [-n] [-v[v]]
    [-O orgname] [--profile (OV|EV|DV)] [-G | --igtf] [-F friendlyname]
    <COMMAND> <commandargs> ...

    -G (--igtf)     request joint-trust public and IGTF trust (OV required)
    -U email        email address of the user in the portal
    -R file         file with a PEM formatted CSR (only key is used)
                    (the default is AUTO, which creates a fresh rsa:4096
                    request in a subdirectory names after the first
                    domain name, i.e. cert's friendlyName)
                    AUTO requests need `openssl` to be installed
    -F name         name used for request and directory naming
    -O orgname      organisation name to use for OV/EV issuance (required if
                    more than one org matches the given domainlist)
    --profile xv    Set cert profile to OV, EV, DV, ... (default OV)
    -d dir          base directory for per-certificate/request directories
    -A              create advanced formats on download (requires openssl)
    -pkcs12_opts op add <op> as extra options to the openssl pkcs12 -export
                    command line (e.g. "-passout pass:plain")
    -e url          HARICA API endpoint (https://cm-stg.harica.gr)
    -v[v...]        become (ver|very)bose
    -h              this help
    -n | --dryrun   do not actually do persistent actions changing state

    -s file         JSON file containing the TOTP shared secrets
        default TOTP secrets JSON is /m/doc/otp_accounts_*.json
        (can also be set using the ANDOTPJSON environment variable)
    -t name         name of the TOTP token in the secrets file
    -P file         password for the user is by default in 
                      /m/security/HARICA-TCS/cm-stg.davidg.passphrase
        (please make sure this is on an empheral encrypted filesystem)

Commands
--------
req <domain> [<domain> ...]

    submit a request with these domain names, and (if AUTO request)
    store the result in a subdirectory named after the first domain
    or friendly name ("./tcs-<domain>/").
    Returns the ID of the request (a UUID). If set to auto, will
    also put this in the "id-<domainname" meta-data file for reference

    Example: tcsg5-apitool -R AUTO req sso.nikhef.nl

dl <uuid>

    download a validated and issued certificate for order <uuid>. This
    <uuid> is shown after the request has been submitted, but can also
    be retrieved from the HARICA CM portal and (if AUTO modus) from the
    'id-' file in the subdirectory for the request

    Example: tcsg5-apitool dl 59af3920-0994-4e80-b2cd-b39a81dac9e2

orglist <domain> [<domain> ...]

    list the organisations that can issue for the provided list of
    domains (in combination with your own account privileges).

    Example: tcsg5-apitool orglist nikhef.nl achtbaan.nationalespeeltuin.nl

there are no other valid commands (yet). To approve requests by the
second-pair-of-eyes, use the HARICA CM portal for now. In the future,
this tool may have dual-user/approver support.
Important: this tool ONLY works with PREVALIDATED domains.

The utility uses the plain-text backup JSON format from andOTP to read
the secrets, and the labels + issuers associated with these. This makes
a perl-based alternative to having your totp device handy.
File should have JSON syntax like: 
  [ { "algorithm" : "SHA1", "digits" : 6, "period" : 30, "type" : "TOTP",
      "issuer" : "token-name-here", "label" : "label-set-by-issuer",
      "secret" : "VERYVERYSECRETDATAISHIDDENINHERE" } ]

If the token secrets file or the password file cannot be opened, then
the script will ask for a response on the terminal.  But be quick for the 
TOTP token entry!

The tool will parse (perl-syntax) rc files from ~/.tcsg5apirc or like 
files (~/.haricarc, /etc/tcsg5apirc, /etc/haricarc, and /usr/local/etc/...)
to overwrite some of the defaults on a per-user basis (like the password
and totp secrets file)

Example of a $HOME/.haricarc file:

    # @(#)tcsg5apirc
    $::cmusername = 'davidg@nikhef.nl';
    $::tokensecjsonpat="/mnt/secured/otpbackup/otp_accounts_*.json";
    $::tokenname = "HARICA STG DAVIDG";
    $::cmpasswordfile = "/mnt/secured/HARICA-TCSG5/cm-stg.davidg.passphrase";
    $::cm_endpoint = "https://cm-stg.harica.gr";
    $::profile = "OV";
    $::basedir = ".";
    $::ossl_pkcs12_extra_opts = "-passout pass:";
    $::orgname = "Nikhef ".
        "(Stichting Nederlandse Wetenschappelijk Onderzoek Inst.)";

KNOWN LIMITATIONS
-----------------
- No name component should contain a comma (","). If there are commas, then 
  auto-EE detection will not work. That's usually harmless, but just in case.
- For AUTO requests, and for advanced output formats (P7B DER, PKCS12) you
  will need OpenSSL 1+ installed. Also on Windows. Use WSL, Cygwin, or a 
  Win32 build of OpenSSL.
- The Digest::HMAC_SHA1 and MIME::Base32 modules are only needed to generate
  the totp token. If you do not like that, or do not have them, comment them
  out and start frantically typing digits from your totp app.


-----------------------------------------------------------------------------
probecert - show TLS and certificate (chain) information
-----------------------------------------------------------------------------
The ProbeCert tool shows the actual certificate and chain content
in nework endpoints and files, including some basic certificate information.

Usage: probecert [-p port] [-v|-q] [-TLS] hostname-of-filename

    -p port       connect to tcp port <port>, default: 443
    -v            be verbose
    -q            be silent
    -TLS          use STARTTLS rather than SSL handshake

and produces something like

$ probecert nationalespeeltuin.nl
Hostname: nationalespeeltuin.nl
Serial Number:55:38:2E:82:4C:C9:E0:A3:C0:1D:96:A6:DD:D3:34:BC:
Issuer: C = GR, O = Hellenic Academic and Research Institutions CA, CN = GEANT TLS RSA 1
Not After : May 21 09:22:11 2026 GMT
Subject: C = NL, L = Amsterdam, O = Nikhef, CN = achtbaan.nationalespeeltuin.nl
SubjectAltNames:
  achtbaan.nationalespeeltuin.nl
  achtbaan.nikhef.nl
  nationalespeeltuin.nl
  www.nationalespeeltuin.nl
  achtbahn.nikhef.nl
  xn--2k8h.nikhef.nl
Modulus: BD:80:A6:1B:72:8C:0C:47:99 ...
Certificate chain supplied by host:
 0 s:C = NL, L = Amsterdam, O = Nikhef, CN = achtbaan.nationalespeeltuin.nl
   i:C = GR, O = Hellenic Academic and Research Institutions CA, CN = GEANT TLS RSA 1
 1 s:C = GR, O = Hellenic Academic and Research Institutions CA, CN = GEANT TLS RSA 1
   i:C = GR, O = Hellenic Academic and Research Institutions CA, CN = HARICA TLS RSA Root CA 2021
 2 s:C = GR, O = Hellenic Academic and Research Institutions CA, CN = HARICA TLS RSA Root CA 2021
   i:C = GR, L = Athens, O = Hellenic Academic and Research Institutions Cert. Authority, CN = Hellenic Academic and Research Institutions RootCA 2015

or, from a file:

$ probecert /m/security/webcerts/tcsg5/tcs-nationalespeeltuin.nl/cert-nationalespeeltuin.nl.pem
File: /m/security/webcerts/tcsg5/tcs-nationalespeeltuin.nl/cert-nationalespeeltuin.nl.pem
Issuer: C = GR, O = Hellenic Academic and Research Institutions CA, CN = GEANT TLS RSA 1
Not Before: May 21 09:22:11 2025 GMT
Not After : May 21 09:22:11 2026 GMT
Subject: C = NL, L = Amsterdam, O = Nikhef, CN = achtbaan.nationalespeeltuin.nl
SubjectAltNames:
  achtbaan.nationalespeeltuin.nl
  achtbaan.nikhef.nl
  nationalespeeltuin.nl
  www.nationalespeeltuin.nl
  achtbahn.nikhef.nl
  xn--2k8h.nikhef.nl
Modulus: BD:80:A6:1B:72:8C:0C:47:99 ...
Serial:  55382E824CC9E0A3C01D96A6DDD334BC


-----------------------------------------------------------------------------
listcerts.sh - list some detail of each PEM blobs in a file
-----------------------------------------------------------------------------

disassemble and provide info about PEM blobs in a composite file. For example:

$ listcerts.sh /m/security/webcerts/tcsg5/tcs-nationalespeeltuin.nl/bundle-nationalespeeltuin.nl.pem
Processing files /m/security/webcerts/tcsg5/tcs-nationalespeeltuin.nl/bundle-nationalespeeltuin.nl.pem
---
PEM blob 1 with 46 lines in /m/security/webcerts/tcsg5/tcs-nationalespeeltuin.nl/bundle-nationalespeeltuin.nl.pem:
  issuer=/C=GR/O=Hellenic Academic and Research Institutions CA/CN=GEANT TLS RSA 1
  subject=/C=NL/L=Amsterdam/O=Nikhef/CN=achtbaan.nationalespeeltuin.nl
  serial=55382E824CC9E0A3C01D96A6DDD334BC
  notBefore=May 21 09:22:11 2025 GMT
  notAfter=May 21 09:22:11 2026 GMT
  SHA1 Fingerprint=95:53:7A:96:DF:B9:EA:30:FE:F7:27:DC:8D:4E:A1:43:B6:3F:DB:1D
---
PEM blob 2 with 35 lines in /m/security/webcerts/tcsg5/tcs-nationalespeeltuin.nl/bundle-nationalespeeltuin.nl.pem:
  issuer=/C=GR/O=Hellenic Academic and Research Institutions CA/CN=HARICA TLS RSA Root CA 2021
  subject=/C=GR/O=Hellenic Academic and Research Institutions CA/CN=GEANT TLS RSA 1
  serial=14D57BF3692228219A5567FA91651B22
  notBefore=Jan  3 11:15:00 2025 GMT
  notAfter=Dec 31 11:14:59 2039 GMT
  SHA1 Fingerprint=BE:7F:0B:36:F8:8A:22:DD:DE:D3:62:DB:9A:F7:9C:8E:65:82:B9:19
---
PEM blob 3 with 39 lines in /m/security/webcerts/tcsg5/tcs-nationalespeeltuin.nl/bundle-nationalespeeltuin.nl.pem:
  issuer=/C=GR/L=Athens/O=Hellenic Academic and Research Institutions Cert. Authority/CN=Hellenic Academic and Research Institutions RootCA 2015
  subject=/C=GR/O=Hellenic Academic and Research Institutions CA/CN=HARICA TLS RSA Root CA 2021
  serial=2A6086D4D4DE45C95E4B98FBBF2FBF26
  notBefore=Sep  2 07:41:55 2021 GMT
  notAfter=Aug 31 07:41:54 2029 GMT
  SHA1 Fingerprint=71:40:C4:0C:28:00:A5:C6:05:23:CE:BF:68:2D:13:4E:D1:7E:DB:0E


-----------------------------------------------------------------------------
nik-acme-certupdate - ACME External Key Binding managed/protected client
-----------------------------------------------------------------------------

Update (when needed) a certificate using the ACME protocol with pre-validated
domains, e.g., from the TCSG4 Sectigo ACME endpoints (but any EAB ACME
endpoint can be used). It will check the domain list for this host, make
sure the installed certificates (by default in /etc/pki/tls/tcsg4/) are
as-expected, and will renew them when needed - because the domain list changed
or the cert will soon expire. The script is intentionally paranoid, even more
so that certbot, so that there is always a reasonable cert remaining.
It optionally cleanses archaic and wrong roots from the certificate chain (as
is needed for AAA Certificate Services by Sectigo).

This utility is particularly suited to be invoked from cron - it will just
check and do nothing unless there is actually actions required. It will not
even talk to the ACME endpoint if everything is fine. You can run it as
often as you want, but typically:

  45 8 * * 1,3,4 root /usr/local/bin/nik-acme-certupdate

is a good startingpoint.

Prerequisites: bash, certbot, openssl [v1+], sed, date, mktemp, diff, logger
     Optional: tcsg4-clean-certchain [to remove antiquated certificate chain]

The "TARGETDIR" variable sets the place where consumers (like a web server
daemon) will expect to find a stable set of keys and certificates. So you
should not point the web server to directly read from the things generated
by certbot. It matches the tcsg4-install-servercert.sh directory structure.

Other useful things go into the mndatory configuration file at
/usr/local/etc/nik-acme-certupdate.config (by default).

It should contain at keast KID and HMAC, and may override the local defaults:

 KID=Dc1...
 HMAC=mv_3kv....
 CERTSERVER=https://acme.enterprise.sectigo.com
 CERTNAME=`hostname -f`
 DOMAINS=....
 TARGETOWNER=openldap
 TARGETGROUP=root
 TARGETPERMS=0640
 TARGETDIR=/etc/pki/tls/tcsg4
 POSTRUN=


-----------------------------------------------------------------------------
districert.sh - copy certificates manually to hosts
-----------------------------------------------------------------------------
Explicitly copy certificates, keys, and chains to a target host and
optionally restart web or other servers. 

Usage: /home/davidg/bin/districert.sh [-R] [-d destdir (tcsg4)] [-p destpath (/root)] [-U user]
          [-s srcdir] [-H] [-S service] [hostname]
  -s dir  source directory for cert files and keys (default: .)
  -d dir  subdirectory on the target that data will be places in
          (default: .../tcsg4)
  -p dir  destination top-level path. Defaults to /root if
          user is root, the user homedir (e.g. /home/root)
          otherwise. -R will overrule this setting
  -R      copy files to the EL-destigated place (/etc/pki/tls/tcsg4)
  -U user use <user> as the userid on the target system (default: root)
  -O ownr use <ownr> as the file owner on target system (default: root)
  -K keyp set key permissions to <keyp> (default: 0600)
  -A      use apt-get, not yum, to ensure remote rsync is present
  -H      run "systemctl restart httpd" on the target afterwards
  -S srv  run "systemctl restart <srv>" on the target afterwards


-----------------------------------------------------------------------------
CAVEATS
-----------------------------------------------------------------------------
These tools come with no warranties whatsoever, and may cause your pet to
walk out on you. Beware! See https://www.nikhef.nl/pdp/doc/experimental-services

