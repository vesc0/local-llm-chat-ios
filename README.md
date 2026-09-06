# Local LLM Chat for iOS

Chat with large language models on iPhone and iPad — either fully on-device via
Apple's MLX framework, or against an Ollama server on your network.

## Features

- **Two inference engines** — MLX-Swift for on-device generation on Apple silicon,
  or Ollama over the local network for heavier models.
- **Multimodal input** — attach images (sent to vision-capable Ollama models) and
  PDF or text documents (extracted and prepended to the prompt).
- **Reasoning models** — `<think>` traces are separated from the answer and shown
  in a collapsible section with elapsed thinking time.
- **On-device model management** — download any MLX-compatible Hugging Face repo
  by id, then browse, select, and delete what you have downloaded.
- **Persistent history** — conversations, attachments, and settings survive relaunch.

## Requirements

- iOS 17 or newer
- Xcode 15 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — the Xcode project is generated,
  not checked in

## Getting started

```bash
git clone https://github.com/vesc0/local-llm-chat-ios.git
cd local-llm-chat-ios
xcodegen generate
open LocalLLMChat.xcodeproj
```

Wait for Swift Package Manager to resolve, pick a device or simulator, and run.

## Testing

```bash
xcodebuild test -project LocalLLMChat.xcodeproj -scheme LocalLLMChat -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Do **not** pass `-sdk iphonesimulator`. It forces the swift-syntax macro plugin
behind `#huggingFaceLoadModelContainer` to build for iOS instead of the host,
and the build fails to resolve `SwiftCompilerPlugin`.

## Configuration

### Ollama

1. Start Ollama on your machine and make sure it listens on your LAN
   (`OLLAMA_HOST=0.0.0.0 ollama serve`).
2. In the app, open Settings, choose **Ollama (Network)**, and enter the host —
   for example `http://192.168.1.10:11434`.
3. Pick a model under **Select Ollama Model**.

Use an IP address rather than a hostname. App Transport Security exempts IP
literals and `.local` names from its HTTPS requirement, so plain `http://` to a
hostname would be blocked.

### MLX

1. In Settings, choose **MLX-Swift (Local)**.
2. Enter a Hugging Face repo id — for example
   `mlx-community/Llama-3.2-1B-Instruct-4bit` — and download it.
3. Select it under **Manage Downloaded Models**.

## Project structure

```
LocalLLMChat/
  App/         entry point and root split view
  Models/      Codable domain types
  Services/    inference backends, persistence, model downloads
  ViewModels/  ChatViewModel
  Views/       SwiftUI screens
Tests/         unit tests
project.yml    XcodeGen manifest — the source of truth for the Xcode project
```

Inference backends conform to `ChatService`, which exposes a single
`stream(_:) -> AsyncThrowingStream<String, Error>`. `ChatViewModel` receives a
store and a service factory through its initializer, so tests substitute stubs
without touching the network or the filesystem.

## Dependencies

- [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) — on-device inference
- [swift-huggingface](https://github.com/huggingface/swift-huggingface) — model downloads
- [swift-transformers](https://github.com/huggingface/swift-transformers) — tokenization

All three are pinned to exact revisions in `project.yml`; they publish no release
tags on `main`.
