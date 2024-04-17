
import pip

def require(package: str) -> object:
    """Implementation of Node.js's `require`. \n
    This function imports the modules at runtime, but if it cannot find them, it uses pip to install them

    Args:
        package (str): the name of the package

    Returns:
        object: the module
    """
    try:
        return __import__(package)
    except ImportError:
        pip.main(['install', package])
        return __import__(package)
    except:
        print(f"Pakcage \"{package}\" couldn't be installed, as a resoult require couldn't import it :(")
