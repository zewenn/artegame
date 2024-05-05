
import os, time

def get_py_files_in_dir(directory: str):
    # Get the list of files in the directory
    file_list: list[str] = []
    for index, filename in enumerate(os.listdir(directory)):
        if filename.endswith(".py"):
            file_list.append("\nfrom scripts import " + filename.replace(".py", ""))
            out_txt = f"Importing scripts: {filename} | {index + 1}/{len(file_list)}"
            out_txt += " "*(os.get_terminal_size().columns - len(out_txt))
            print(out_txt, end='\r')
    print("")
    return file_list

def init():
    with open(os.path.join("brass", "src", "script_import.py"), "w", encoding="utf8") as wf:
        content: list[str] = []

        help_line: str = f"# Importing scripts, so they can run"
        import_line: str = ' '.join(get_py_files_in_dir(os.path.join("brass", "scripts")))
        
        if len(content) < 4:
            for i in range(4):
                content.append("")

        content[2] = help_line
        content[3] = import_line

        wf.write("\n".join(content))

if __name__ == "__main__":
    init()