#!/usr/bin/env python3
"""Offline NFC door controller.

The magnetic lock is fail-secure in normal operation:

* GPIO 27 LOW  -> MOSFET on  -> lock powered/locked
* GPIO 27 HIGH -> MOSFET off -> lock unpowered/unlocked

No card identifiers or card contents are read or logged.
"""

from __future__ import annotations

import logging
import signal
import subprocess
import threading

from smartcard.CardMonitoring import CardMonitor, CardObserver


GPIO = 27
UNLOCK_SECONDS = 30
CONTACTLESS_READER_MARKER = "contactless"

LOCKED_LEVEL = "dl"
UNLOCKED_LEVEL = "dh"


def set_gpio(level: str) -> None:
    subprocess.run(
        ["/usr/bin/pinctrl", "set", str(GPIO), "op", level],
        check=True,
    )


def is_contactless(card: object) -> bool:
    reader = getattr(card, "reader", "")
    return CONTACTLESS_READER_MARKER in str(reader).lower()


class TokenObserver(CardObserver):
    def __init__(
        self,
        token_seen: threading.Event,
        token_removed: threading.Event,
    ) -> None:
        self._token_seen = token_seen
        self._token_removed = token_removed

    def update(self, observable: object, actions: tuple[list[object], list[object]]) -> None:
        added_cards, removed_cards = actions

        if any(is_contactless(card) for card in removed_cards):
            self._token_removed.set()

        if any(is_contactless(card) for card in added_cards):
            self._token_removed.clear()
            self._token_seen.set()


class DoorController:
    def __init__(self) -> None:
        self._stop = threading.Event()
        self._token_seen = threading.Event()
        self._token_removed = threading.Event()
        self._monitor = CardMonitor()
        self._observer = TokenObserver(self._token_seen, self._token_removed)

    def request_stop(self, signum: int, frame: object) -> None:
        logging.info("Stop requested")
        self._stop.set()
        self._token_seen.set()
        self._token_removed.set()

    def lock(self) -> None:
        set_gpio(LOCKED_LEVEL)
        logging.info("Door locked")

    def unlock(self) -> None:
        set_gpio(UNLOCKED_LEVEL)
        logging.info("Door unlocked for %d seconds", UNLOCK_SECONDS)

    def wait_for_token_removal(self) -> None:
        while not self._stop.is_set() and not self._token_removed.wait(1):
            pass

    def run(self) -> None:
        self.lock()
        self._monitor.addObserver(self._observer)
        logging.info("NFC door controller ready")

        try:
            while not self._stop.is_set():
                if not self._token_seen.wait(1):
                    continue

                self._token_seen.clear()
                if self._stop.is_set():
                    break

                logging.info("NFC token detected")
                self.unlock()
                self._stop.wait(UNLOCK_SECONDS)
                self.lock()

                if not self._token_removed.is_set():
                    logging.info("Waiting for NFC token removal")
                    self.wait_for_token_removal()

                self._token_removed.clear()
        finally:
            self._monitor.deleteObserver(self._observer)
            self.lock()


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    controller = DoorController()
    signal.signal(signal.SIGTERM, controller.request_stop)
    signal.signal(signal.SIGINT, controller.request_stop)
    controller.run()


if __name__ == "__main__":
    main()
