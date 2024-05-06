import os, time
from zenyx import printf
from result import Result, Ok, Err
import __config__ as conf

def generate_imports_from_directory(directory: str) -> Result[list[str], ValueError]:
    if (not directory.endswith("routines")):
        return Err(ValueError("Incorrect path to scripts."))

    # Get the list of files in the directory
    file_list: list[str] = []
    for index, filename in enumerate(os.listdir(directory)):
        if filename.endswith(".py"):
            file_list.append("\nfrom routines import " + filename.replace(".py", ""))
            out_txt = f"[{index + 1}/{len(file_list)}] Binding Routines: {filename}"
            printf.full_line(out_txt, end="\r")
    print("")
    return Ok(file_list)


def serialise_imports():
    """
    Binding a script adds it to the `script_import.py` file as an import, 
    thus the script runs when the file is loaded.\n
    This is needed with the use event decorators, which - on load - bind functions to events.
    """

    with open(
        os.path.join("brass", "src", conf.ROUTINE_IMPORT_FILE_NAME), "w", encoding="utf8"
    ) as wf:
        content: list[str] = []

        help_line: str = f"# Importing scripts, so they can run"
        
        import_list = generate_imports_from_directory(os.path.join(*conf.ROUTINE_PATH))
        if (import_list.is_err()):
            printf("Failed to import scripts: Wrong path")
            return
        
        import_line: str = " ".join(
            import_list.ok()
        )

        if len(content) < 4:
            for i in range(4):
                content.append("")

        content[2] = help_line
        content[3] = import_line

        wf.write("\n".join(content))


if __name__ == "__main__":
    serialise_imports()
