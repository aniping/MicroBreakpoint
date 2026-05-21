from flask import Flask
from flask_cors import CORS

from app.api.breakpoint_api import bp_api
from app.api.call_api import call_api
from app.api.interface_api import interface_api
from app.api.session_api import session_api
from app.api.state_api import state_api
from app.db.database import init_db


def create_app(test_config=None):
    app = Flask(__name__)
    app.config.update(
        DATABASE=(test_config or {}).get("DATABASE", "data/debugger.sqlite3"),
        TESTING=bool(test_config and test_config.get("TESTING")),
    )
    CORS(app)
    init_db(app)
    app.register_blueprint(session_api)
    app.register_blueprint(state_api)
    app.register_blueprint(call_api)
    app.register_blueprint(interface_api)
    app.register_blueprint(bp_api)
    return app
