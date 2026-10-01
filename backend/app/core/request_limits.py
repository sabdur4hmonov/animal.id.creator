"""Bound whole requests before multipart parsing/spooling."""

from starlette.responses import JSONResponse


class RequestSizeLimit:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope["method"] not in ("POST", "PUT", "PATCH"):
            return await self.app(scope, receive, send)
        limit = scope["app"].state.settings.max_upload_bytes + 64 * 1024
        headers = dict(scope["headers"])
        if b"content-length" in headers:
            try:
                size = int(headers[b"content-length"])
                if size < 0:
                    raise ValueError
            except ValueError:
                return await JSONResponse({"detail": "Invalid Content-Length"}, 400)(scope, receive, send)
            if size > limit:
                return await JSONResponse({"detail": "Request exceeds upload limit"}, 413)(
                    scope, receive, send
                )
        chunks, size = [], 0
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            size += len(message.get("body", b""))
            if size > limit:
                return await JSONResponse({"detail": "Request exceeds upload limit"}, 413)(
                    scope, receive, send
                )
            chunks.append(message)
            if not message.get("more_body", False):
                break
        iterator = iter(chunks)

        async def bounded_receive():
            return next(iterator, {"type": "http.request", "body": b"", "more_body": False})

        return await self.app(scope, bounded_receive, send)
