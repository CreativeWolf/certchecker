## CertChecker
`CertChecker` is a script that takes a domain as input and uses `subfinder` by `projectdiscovery.io` to enumerate and find subdomains,
then checks each subdomain if it's accessible via http and checks for the SSL certificate information to ascertain if the certificate is
`active`, `expired`, or the domain is `unreachable`.

# Background
While trying to access a URL from Supreme Court of India [main.sci.gov.in], observed that the site has an expired certificate, got curious 
to check what other subdomains of sci.gov.in are online with an expired certificate. Extended the idea to a simple script that uses existing 
tools to quickly scan a domain and report on its subdomains and their certificate status.

**Important:** Depends on `subfinder` by `projectdiscovery.io` (https://github.com/projectdiscovery/subfinder).

## Installation:

To install `CertChecker`, follow these steps:

```
git clone https://github.com/creativewolf/CertChecker.git && cd CertChecker && sudo chmod +x certchecker.sh"
```
