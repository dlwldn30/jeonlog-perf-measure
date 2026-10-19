"""측정용 로컬 JWT 생성 (HS256). 앱에 넣은 더미 JWT_SECRET과 같은 값을 쓴다."""
import base64, hashlib, hmac, json, sys, time

secret = (sys.argv[1] if len(sys.argv) > 1 else "measure-dummy-secret-measure-dummy-secret-measure-dummy-secret-0123456789").encode()
b64 = lambda d: base64.urlsafe_b64encode(d).rstrip(b"=")

header = b64(json.dumps({"alg": "HS256"}).encode())
# seed.sql의 사용자 1번(oauth_provider=GOOGLE, oauth_id=oid1)
payload = b64(json.dumps({"sub": "GOOGLE:oid1", "role": "USER", "iat": int(time.time()), "exp": int(time.time()) + 3600}).encode())
sig = b64(hmac.new(secret, header + b"." + payload, hashlib.sha256).digest())
print((header + b"." + payload + b"." + sig).decode())
