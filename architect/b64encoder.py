import base64, os
import __config__ as CONFIG
from zenyx import printf

def get_files_in_directory(directory) -> list[str]:
    # Get the list of files in the directory
    file_list = []
    for filename in os.listdir(directory):
        file_path = os.path.join(directory, filename)
        if os.path.isfile(file_path):
            file_list.append(file_path)
    return file_list


def serialize_file_to_b64string(filepath) -> str:
    with open(filepath, "rb") as image_file:
        # Read the binary data of the image file
        binary_data = image_file.read()
        
        # Encode the binary data to Base64
        base64_encoded = base64.b64encode(binary_data)
        
        # Convert the bytes to a string
        base64_string = base64_encoded.decode("utf-8")
        
    return base64_string

# Example usage
# image_path = "D:\\py\\brass\\assets\\test.png"
# serialized_image = serialize_image_to_string(image_path)

# # Now 'serialized_image' contains the Base64-encoded string representation of the image
# # print(serialized_image)

# with open("res.txt", "w") as wf:
#     wf.write(serialized_image)

def serialise():
    images: list = get_files_in_directory(os.path.join("brass", "assets"))
    img_dict: dict = {}

    for index, image in enumerate(images):
        basename: str = os.path.basename(image)
        img_dict[basename] = serialize_file_to_b64string(image)
        printf.full_line(f"[{index + 1}/{len(images)}] Serialising Assets: {basename}", end='\r')
    print("")
        # time.sleep(1)
    # print(f"REFERENCE_TABLE: dict = {img_dict}")

    with open(os.path.join("brass", "src", f"{CONFIG.ASSETS_FILE_NAME}"), "w") as wf:
        wf.write(f"REFERENCE_TABLE: dict = {img_dict}")

if __name__ == "__main__":
    serialise()