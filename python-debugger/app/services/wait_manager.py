from threading import Event, Lock


class WaitManager:
    def __init__(self):
        self._events = {}
        self._lock = Lock()

    def create(self, call_id):
        with self._lock:
            event = self._events.get(call_id)
            if event is None:
                event = Event()
                self._events[call_id] = event
            return event

    def wait(self, call_id, timeout=300):
        event = self.create(call_id)
        ok = event.wait(timeout=timeout)
        with self._lock:
            self._events.pop(call_id, None)
        return "continue" if ok else "timeout_continue"

    def continue_one(self, call_id):
        with self._lock:
            event = self._events.pop(call_id, None)
        if event:
            event.set()
            return True
        return False

    def continue_all(self):
        with self._lock:
            items = list(self._events.values())
            self._events.clear()
        for event in items:
            event.set()
        return len(items)


wait_manager = WaitManager()
