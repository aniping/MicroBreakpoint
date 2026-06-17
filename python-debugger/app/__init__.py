from pathlib import Path

from flask import Flask
from flask_cors import CORS

from app.api.breakpoint_api import bp_api
from app.api.call_api import call_api
from app.api.interface_api import interface_api
from app.api.payload_api import payload_api
from app.api.session_api import session_api
from app.api.state_api import state_api
from app.db.database import init_db
from app.services.debug_service import STATE, restore_session_state
from app.services.wait_manager import wait_manager


def create_app(test_config=None):
    app = Flask(__name__)
    database = (test_config or {}).get("DATABASE", "data/debugger.sqlite3")
    config = test_config or {}
    settings_file = config.get("SETTINGS_FILE")
    if settings_file is None and test_config:
        settings_file = str(Path(database).resolve().parent / "settings.json")
    app.config.update(
        DATABASE=database,
        PAYLOAD_ROOT=config.get("PAYLOAD_ROOT") if test_config else None,
        SETTINGS_FILE=settings_file,
        TESTING=bool(test_config and test_config.get("TESTING")),
    )
    if app.config["PAYLOAD_ROOT"] is None and database != ":memory:":
        app.config["PAYLOAD_ROOT"] = str(Path(database).resolve().parent / "payloads")
    CORS(app)
    init_db(app)
    wait_manager.continue_all()
    STATE.update(debugging=False, mode="idle", sessionId=None)
    with app.app_context():
        restore_session_state()
    app.register_blueprint(session_api)
    app.register_blueprint(state_api)
    app.register_blueprint(call_api)
    app.register_blueprint(payload_api)
    app.register_blueprint(interface_api)
    app.register_blueprint(bp_api)
    return app
