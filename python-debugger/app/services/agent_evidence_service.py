from hashlib import sha256

from app.services.agent_interaction_analysis_service import differences, entity, interaction, interaction_row


def build_evidence(payload):
    ids = [str(item) for item in payload.get("interaction_ids", []) if str(item)]
    focus = str(payload.get("focus") or "")
    if not ids:
        return {"ok": False, "status": "invalid_request", "message": "interaction_ids 不能为空。", "entities": []}
    interactions = []
    for interaction_id in ids:
        row = interaction_row(interaction_id)
        if not row:
            return {"ok": False, "status": "not_found", "message": f"交互记录不存在：{interaction_id}", "entities": []}
        interactions.append(interaction(row))
    diff_items = pairwise_differences(interactions)
    payload_refs = payload_ref_list(interactions)
    bundle_id = "evb-" + sha256((focus + "|" + "|".join(ids)).encode("utf-8")).hexdigest()[:16]
    entities = [entity("evidence_bundle", bundle_id, focus or "Evidence bundle", "available")]
    entities.extend(entity("interaction", item["interaction_id"], item["label"], item["status"]) for item in interactions)
    entities.extend(entity("payload", item["payload_ref"], item["label"], "available") for item in payload_refs)
    return {
        "ok": True,
        "status": "available",
        "evidence_bundle_id": bundle_id,
        "focus": focus,
        "interactions": interactions,
        "differences": diff_items,
        "payload_refs": payload_refs,
        "findings": findings(interactions, diff_items),
        "entities": entities,
    }


def pairwise_differences(interactions):
    if len(interactions) < 2:
        return []
    base = interactions[0]
    result = []
    for item in interactions[1:]:
        for diff in differences(base, item):
            enriched = dict(diff)
            enriched["left_interaction_id"] = base["interaction_id"]
            enriched["right_interaction_id"] = item["interaction_id"]
            result.append(enriched)
    return result


def payload_ref_list(interactions):
    result = []
    for item in interactions:
        add_payload_ref(result, item, "request_payload_ref", "request")
        add_payload_ref(result, item, "response_payload_ref", "response")
    return result


def add_payload_ref(result, interaction_item, key, payload_type):
    payload_ref = interaction_item.get(key)
    if not payload_ref:
        return
    result.append({
        "payload_ref": payload_ref,
        "interaction_id": interaction_item["interaction_id"],
        "payload_type": payload_type,
        "label": f"{interaction_item['label']} {payload_type}",
    })


def findings(interactions, diff_items):
    result = [{"kind": "fact", "title": "交互数量", "message": f"证据包包含 {len(interactions)} 次交互。"}]
    for item in interactions:
        if item.get("exception_summary"):
            result.append({
                "kind": "fact",
                "title": "异常交互",
                "message": f"{item['interaction_id']} 存在异常：{item['exception_summary']}",
            })
    if diff_items:
        result.append({"kind": "fact", "title": "交互差异", "message": f"已发现 {len(diff_items)} 个轻量字段差异。"})
    return result
