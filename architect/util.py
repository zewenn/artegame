from zenyx import printf
import time

def shorten(filename: str) -> str:
    return filename[:16] + ("..." if len(filename) > 16 else "")


def task(task_name: str):
    def wrap(fn):
        def res(*args, **kwargs):
            printf.full_line(f"\n@![Task : {task_name}] $&")
            r = fn(*args, **kwargs)
            return r

        return res

    return wrap


def progress_bar(at: int, top: int, msg: str) -> str:
    percent = round(at / top * 15, 5)
    progress = round(percent)
    line = "█" * progress + " " * (15 - progress)
    printf.full_line(f" {round(at / top * 100)}%|{line}| {at}/{top},", msg, end="\r")
    # time.sleep(0.05)


def task_complete():
    # printf.full_line(" Task completed @!successfully$&!")
    print("")