# NoMercyFFMpeg

NoMercyFFMpeg is a collection of Dockerfiles designed to build FFmpeg for various platforms, including Linux, Windows, and macOS. These Dockerfiles facilitate the compilation of FFmpeg with custom configurations tailored to specific operating systems and architectures.

## Features

- **Cross-Platform Support**: Provides Dockerfiles for building FFmpeg on multiple platforms:
  - `ffmpeg-linux.dockerfile`
  - `ffmpeg-windows.dockerfile`
  - `ffmpeg-darwin-arm64.dockerfile`
  - `ffmpeg-darwin-x86_64.dockerfile`
  - `ffmpeg-aarch64.dockerfile`
- **Customizable Builds**: Each Dockerfile can be modified to include specific FFmpeg configurations, codecs, and dependencies as required.

## Getting Started

To build FFmpeg using the provided Dockerfiles, follow these steps:

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/NoMercy-Entertainment/NoMercyFFMpeg.git
   cd NoMercyFFMpeg
   ```

2. **Build the Docker Image**:
   Choose the appropriate Dockerfile for your target platform and build the image. For example, to build for Linux:
   ```bash
   docker build -f ffmpeg-linux.dockerfile -t ffmpeg-linux .
   ```
   Replace `ffmpeg-linux.dockerfile` with the desired Dockerfile for other platforms.

3. **Run the Docker Container**:
   After building the image, you can run a container to use the compiled FFmpeg:
   ```bash
   docker run --rm -v $(pwd):/workspace ffmpeg-linux ffmpeg -version
   ```
   This command mounts the current directory into the container's `/workspace` directory and displays the FFmpeg version to verify the build.

## Customization

To customize the FFmpeg build:

- **Modify Build Arguments**: Edit the `ARG` directives in the Dockerfile to change build parameters such as FFmpeg version or enabled codecs.
- **Add Dependencies**: Install additional packages by modifying the `RUN` commands in the Dockerfile to include necessary dependencies.
- **Apply Patches**: If you need to apply patches to the FFmpeg source, add the patch files to the repository and update the Dockerfile to apply them during the build process.


## Acknowledgments

- [FFmpeg](https://ffmpeg.org/) – A complete, cross-platform solution to record, convert and stream audio and video.

---

*Note: This project is not affiliated with or endorsed by the FFmpeg project.*

## Contributing

Contributions are welcome! If you have improvements or additional Dockerfiles for other platforms, feel free to submit a pull request.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

For further information or support, visit NoMercy.tv or contact our support team.

Made with ❤️ by [NoMercy Entertainment](https://nomercy.tv)
