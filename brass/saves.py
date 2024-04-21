from zenyx import pyon
from dataclasses import dataclass
from classes import Entity, Moment
from copy import deepcopy
from entities import Entities
from load import load
from pgapi import Debugger
import os



class Loader:
    SAVE_URL = [os.path.expanduser("~"), "Arte-Game"]
    SAVE_PATH: str = os.path.join(*SAVE_URL)
    SAVE_FILE = os.path.join(SAVE_PATH, "save.json")


    @classmethod
    def make_url(this):
        if (not os.path.exists(this.SAVE_PATH)):
            os.mkdir(this.SAVE_PATH)

    @classmethod
    def save(this):
        this.make_url()
        for_save = Moment(deepcopy(Entities.entities))
        pyon.dump(for_save, this.SAVE_FILE, 4)
        Debugger.print("Saving...")

    @classmethod
    def load(this):
        this.make_url()

        failed: bool = False

        try:
            loaded: Moment = pyon.load(this.SAVE_FILE)
            Entities.entities = loaded.entities
        except Exception as e:
            Debugger.print(f"Error during loading: {e}")
            failed = True

        if (not os.path.exists(this.SAVE_FILE) or failed):
            Debugger.print("No savefile found")
            load()
            return
