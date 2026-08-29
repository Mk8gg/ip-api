import { FRONTEND_HTML } from './frontend.js'
import { getFlag } from './utils'
import { CORS_HEADERS } from './config'

function getClientIp(request) {
  const candidates = [
    request.headers.get('cf-connecting-ip'),
    request.headers.get('x-real-ip'),
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim(),
    request.headers.get('x-client-ip')
  ]
  return candidates.find(Boolean) || ''
}

async function lookupIp(ip) {
  const endpoint = ip
    ? `https://ipapi.co/${encodeURIComponent(ip)}/json/`
    : 'https://ipapi.co/json/'
  const response = await fetch(endpoint, {
    headers: { accept: 'application/json', 'user-agent': 'ip-api/1.0' }
  })
  if (!response.ok) throw new Error(`Geolocation provider returned ${response.status}`)
  const data = await response.json()
  if (data.error) throw new Error(data.reason || 'Geolocation lookup failed')
  return data
}

export default {
  async fetch(request) {
    const ip = getClientIp(request)
    const { pathname } = new URL(request.url)
    const wantsHtml = request.headers.get('accept')?.includes('text/html')

    if (pathname === '/' && wantsHtml) {
      return new Response(FRONTEND_HTML, {
        headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' }
      })
    }

    if (pathname === '/geo') {
      try {
        const data = await lookupIp(ip)
        const countryCode = data.country_code || data.country || ''
        const geo = {
          version: data.version || '',
          flag: countryCode.length === 2 ? getFlag(countryCode) : '',
          country: data.country_name || countryCode || '',
          countryCode,
          countryCode3: data.country_code_iso3 || '',
          countryRegion: data.region || '',
          regionCode: data.region_code || '',
          city: data.city || '',
          postal: data.postal || '',
          asn: data.asn || '',
          asOrganization: data.org || '',
          latitude: data.latitude ?? null,
          longitude: data.longitude ?? null,
          latlong: data.latlong || '',
          timezone: data.timezone || '',
          utcOffset: data.utc_offset || '',
          continent: data.continent_code || '',
          inEu: data.in_eu ?? null,
          callingCode: data.country_calling_code || '',
          currency: data.currency || '',
          currencyName: data.currency_name || '',
          languages: data.languages || '',
          capital: data.country_capital || '',
          tld: data.country_tld || '',
          area: data.country_area ?? null,
          population: data.country_population ?? null,
          hostname: data.hostname || ''
        }
        return Response.json({ ip: data.ip || ip, ...geo }, {
          headers: { ...CORS_HEADERS, 'cache-control': 'public, max-age=300', 'x-client-ip': data.ip || ip }
        })
      } catch (error) {
        return Response.json({
          ip,
          error: true,
          message: error instanceof Error ? error.message : 'Geolocation lookup failed'
        }, {
          status: 502,
          headers: { ...CORS_HEADERS, 'cache-control': 'no-store', 'x-client-ip': ip }
        })
      }
    }

    return new Response(ip, { headers: { ...CORS_HEADERS, 'x-client-ip': ip } })
  }
}
