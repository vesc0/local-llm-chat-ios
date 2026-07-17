import Foundation
import Hub

let repo = HubApi.Repo(id: "mlx-community/Llama-3.2-1B-Instruct-4bit", type: .models)
let dir = HubApi.shared.localRepoLocation(repo)
print("LOCAL REPO LOCATION: \(dir.path)")
