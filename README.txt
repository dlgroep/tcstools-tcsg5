tcsg5-apitool - HARICA API for TCS Gen5 commissioning

Usage: tcsg5-apitool [-s andOTPfile.json] [-e endpoint] [-t tokenname]
    [-P passwordfile] [-U user_email] [-R csrfile_pem] [-h] [-n] [-v[v]]
    [-O orgname] [--profile (OV|EV|DV)] [-F friendlyname]
    <COMMAND> <commandargs> ...

    -e url          HARICA API endpoint (https://cm-stg.harica.gr)
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
    $::orgname = "Nikhef ".
        "(Stichting Nederlandse Wetenschappelijk Onderzoek Inst.)";

This tool comes with no warranties whatsoever, and may cause your pet to
walk out on you. Beware!
