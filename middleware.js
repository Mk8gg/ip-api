import { ipAddress, geolocation, json } from '@vercel/edge'
import { FRONTEND_HTML } from './src/frontend.js'
import { CORS_HEADERS } from './src/config'

export default function middleware(request) {
  const ip = ipAddress(request)
  const { pathname } = new URL(request.url)
  const wantsHtml = request.headers.get('accept')?.includes('text/html')
  if (pathname === '/' && wantsHtml) {
    return new Response(FRONTEND_HTML, {
      headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'public, max-age=300' }
    })
  }
  console.log(ip, pathname)
  if (pathname === '/geo') {
    const geo = geolocation(request)
    console.log(geo)
    return json({ ip, ...geo }, {
      headers: { ...CORS_HEADERS, 'x-client-ip': ip }
    })
  }
  return new Response(ip, { headers: { ...CORS_HEADERS, 'x-client-ip': ip } })
}
