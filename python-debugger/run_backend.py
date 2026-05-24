from app import create_app
from desktop.config import BACKEND_HOST, BACKEND_PORT

app = create_app()

if __name__ == "__main__":
    app.run(host=BACKEND_HOST, port=BACKEND_PORT, threaded=True)
