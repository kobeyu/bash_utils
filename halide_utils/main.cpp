#include <Halide.h>
#include <halide_image_io.h>

#include <iostream>
#include <fstream>


using namespace Halide;
using namespace Halide::Tools;
using namespace std;


int image2bin(string &path) {

    Halide::Runtime::Buffer<uint8_t> image = load_image(path);

    int width = image.width();
    int height = image.height();
    const std::string opath = path + "_" + to_string(width) + "x" +to_string(height) + ".halide.bin";

    // Open a binary file for writing
    std::ofstream file(opath, std::ios::binary & std::ios::trunc);
    if (file.is_open()) {
        // Write the buffer data to the file
        file.write(reinterpret_cast<char*>(image.data()), image.number_of_elements());
        file.close();
        cout << "image2bin, output file:" << opath << endl;
    } else {
        std::cerr << "Failed to open the file for writing." << std::endl;
    }

    return 0;
}

int GetWidthHeight(string &path, int &width, int &height)
{

    // Find the position of the last underscore
    size_t underscorePos = path.find_last_of('_');

    if (underscorePos != std::string::npos) {
        // Extract the part of the string after the last underscore
        std::string sizeSubstring = path.substr(underscorePos + 1);

        // Find the position of 'x'
        size_t xPos = sizeSubstring.find('x');

        if (xPos != std::string::npos) {
            // Extract the width and height substrings
            std::string widthStr = sizeSubstring.substr(0, xPos);
            std::string heightStr = sizeSubstring.substr(xPos + 1);

            // Convert the width and height strings to integers
            width = std::stoi(widthStr);
            height = std::stoi(heightStr);
        } else {
            std::cerr << "Unable to find 'x' in the string." << std::endl;
        }
    } else {
        std::cerr << "Unable to find the last underscore in the string." << std::endl;
    }

    return 0;

}

string GetFilePrefix(string &path) {

    // Use std::istringstream to split the path by '/'
    std::istringstream ss(path);
    std::string token;
    string prefix;

    while (std::getline(ss, token, '/')) {
        prefix = token; // Update the prefix with the last token
    }

    // Now, 'prefix' contains the file name with extension
    // You can remove the extension to get just the prefix
    size_t dotPos = prefix.find_last_of('_');
    if (dotPos != std::string::npos) {
        prefix = prefix.substr(0, dotPos);
    }
    return prefix;
}

int bin2image(string &path) {

    // Open the binary file for reading
    std::ifstream file(path, std::ios::binary);
    if (file.is_open()) {
        // Get the size of the file
        file.seekg(0, std::ios::end);
        size_t file_size = file.tellg();
        file.seekg(0, std::ios::beg);

        // Create a Halide buffer with the same size
        int width = 0;
        int height = 0;
        const int ch = 3;
        assert(!GetWidthHeight(path, width, height));
        assert(width * height);

        Halide::Runtime::Buffer<uint8_t> buffer(width, height, ch);

        // Read the data from the file into the buffer
        file.read(reinterpret_cast<char*>(buffer.data()), width*height * ch);

        file.close();

        string prefix = GetFilePrefix(path);
        string opath = "output_" + prefix;
        cout << "bin2image, output file:" << opath << endl;
        save_image(buffer, opath);


    } else {
        std::cerr << "Failed to open the file for reading." << std::endl;
    }

    return 0;


}



int main(int argc, char* argv[]) {
    if (argc != 3) {
        cout << "Usage(cpp): " << argv[0] << " <mode> <path>" << endl;
        cout << "\t[mode]:image2bin or bin2image" << endl;
        cout << "\t[path]:path to the file(png or binary)" << endl;
        return 1;
    }

    string runningMode = argv[1];
    string path = argv[2];

    if (runningMode == "image2bin") {
        image2bin(path);
    }
    else if (runningMode == "bin2image") {
        bin2image(path);
    }
    else {
        cout << "Invalid running mode. Use 'image2bin' or 'bin2image'." << endl;
        return 4;
    }

    return 0;
}
