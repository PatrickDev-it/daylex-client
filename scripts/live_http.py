"""The one way the delivery checks read the live services after a publication.

Cloudflare, in front of daylex.it, refuses urllib's default User-Agent with 403, so a check that used it
failed after a correct publication and the recovery workflow republished the same commit again. Every check
names itself here and asks past caches.
"""
import urllib.request

USER_AGENT = 'Daylex-delivery-check/1 (+https://github.com/PatrickDev-it/daylex-client)'


def open_live(url, method='GET'):
    request = urllib.request.Request(url, method=method,
                                     headers={'Cache-Control': 'no-cache', 'User-Agent': USER_AGENT})
    return urllib.request.urlopen(request, timeout=60)
