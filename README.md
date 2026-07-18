# Local LLM Chat for iOS

An iOS application designed to let you interact with Large Language Models (LLMs) both locally on-device and over the network. Built with SwiftUI, it leverages the power of Apple's MLX framework for on-device inference, and integrates with Ollama for network-based inference.

## Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Dependencies](#dependencies)
- [Configuration](#configuration)

## Features

- **Dual Inference Engines:**
  - **MLX-Swift (Local):** Run models entirely on your iPhone/iPad using Apple's MLX framework. Optimized for Apple Silicon.
  - **Ollama (Network):** Connect to a remote or local Ollama server to offload heavy computation.
- **Multimodal Chat Support:** Send images and documents to compatible models.
- **Reasoning Models Support:** Includes a dedicated "Thought Process" visualization layer for reasoning models.
- **On-Device Model Manager:** Browse, download, and manage models directly from the Hugging Face Hub within the app.
- **Persistent Storage:** Chat history, attachments, and application settings are persisted across app sessions in the iOS Sandbox.

## Prerequisites

- iOS 17.0 or newer.
- Xcode 15 or newer.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for generating the Xcode project file).

## Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/vesc0/local-llm-chat-ios.git
   cd local-llm-chat-ios
   ```

2. **Generate the Xcode Project:**
   Since the project structure is defined using `project.yml`, use XcodeGen to generate the `.xcodeproj` file:
   ```bash
   xcodegen generate
   ```

3. **Open and Build:**
   Open the newly generated `LocalLLMChat.xcodeproj` in Xcode. Wait for the Swift Package Manager (SPM) dependencies to resolve, select your target device or simulator, and hit **Run**.

## Dependencies

This project relies on several key open-source packages:
- [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm): For high-performance local inference via MLX.
- [swift-huggingface](https://github.com/huggingface/swift-huggingface) & [swift-transformers](https://github.com/huggingface/swift-transformers): For model downloading, hub integration, and tokenization.

## Configuration

### Ollama Setup
1. Ensure Ollama is running on your host machine.
2. Go to the Model Manager in the app (click on the Settings icon) and select Ollama (Network).
3. Enter your machine's IP address and port (e.g., `http://192.168.1.10:11434`).

### MLX Setup
1. Go to the Model Manager in the app (click on the Settings icon) and select MLX-Swift (Local).
2. Download a supported model from Hugging Face.
3. Select it as your active local model.
