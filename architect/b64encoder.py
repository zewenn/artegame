import base64, os
import __config__ as conf
from util import *

def get_files_in_directory(directory) -> list[str]:
    file_list = []
    for filename in os.listdir(directory):
        file_path = os.path.join(directory, filename)
        if os.path.isfile(file_path):
            file_list.append(file_path)
    return file_list


def serialize_file_to_b64string(filepath) -> str:
    """
    Converts any asset file to a base64 string
    """
    with open(filepath, "rb") as image_file:
        # Read the binary data of the image file
        binary_data = image_file.read()

        # Encode the binary data to Base64
        base64_encoded = base64.b64encode(binary_data)

        # Convert the bytes to a string
        base64_string = base64_encoded.decode("utf-8")

    return base64_string

@task("Serialising Assets")
def serialise() -> None:
    images: list = get_files_in_directory(os.path.join(*conf.ASSETS_DIR_PATH))
    img_dict: dict = {}

    for index, image in enumerate(images):
        basename: str = os.path.basename(image)
        img_dict[basename] = serialize_file_to_b64string(image)
        
        progress_bar(index + 1, len(images), shorten(basename))
    task_complete()

    if not os.path.isdir(os.path.join(*conf.SERIALISED_OUTPUT_DIR)):
        os.mkdir(os.path.join(*conf.SERIALISED_OUTPUT_DIR))

    with open(
        os.path.join(*conf.SERIALISED_OUTPUT_DIR, f"{conf.ASSETS_FILE_DIST_NAME}"), "w"
    ) as wf:
        wf.write(f"REFERENCE_TABLE: dict[str, str] = {img_dict}")


if __name__ == "__main__":
    serialise()
