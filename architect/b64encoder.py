import base64, os

def get_files_in_directory(directory):
    # Get the list of files in the directory
    file_list = []
    for filename in os.listdir(directory):
        file_path = os.path.join(directory, filename)
        if os.path.isfile(file_path):
            file_list.append(file_path)
    return file_list


def serialize_image_to_string(image_path):
    with open(image_path, "rb") as image_file:
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

def init():
    images: list = get_files_in_directory("brass\\assets")
    img_dict: dict = {}

    for index, image in enumerate(images):
        basename: str = os.path.basename(image)
        img_dict[basename] = serialize_image_to_string(image)
        print(f"Compiling Images: {basename} | {index + 1}/{len(images)}        ", end='\r')
    print("")    
    # print(f"REFERENCE_TABLE: dict = {img_dict}")

    with open("brass\\src\\image_b64.py", "w") as wf:
        wf.write(f"REFERENCE_TABLE: dict = {img_dict}")

if __name__ == "__main__":
    init()