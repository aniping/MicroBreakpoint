from flask import Blueprint, jsonify

from app.services.core import state_response

state_api = Blueprint("state_api", __name__, url_prefix="/api")


@state_api.get("/debug/state")
def debug_state():
    return jsonify(state_response())
