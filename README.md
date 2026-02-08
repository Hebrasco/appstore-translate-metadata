# Setup

Create a `AppStoreConfiguration.swift` and `DeepLApiKey.swift` file in the `Sources` folder.

`AppStoreConfiguration.swift`
```Swift
@preconcurrency import AppStoreConnect_Swift_SDK

let APPSTORE_CONFIGURATION = try! APIConfiguration(
    issuerID: "...",
    privateKeyID: "...",
    privateKey: "..."
)
```

`DeepLApiKey.swift`
```Swift
let DEEPL_API_KEY = "..."
```

# Usage

Create a source file that looks like this. All values are optional.
```JSON
{
    "description": "...",
    "keywords": "...",
    "marketingURL": "...",
    "promotionalText": "...",
    "supportURL": "...",
    "whatsNew": "..."
}
```

Then use it like this:

```
USAGE: appstore-translate-metadata <bundle-id> --source-file <source-file> --source-language <source-language> --output-path <output-path> [--marketing-url <marketing-url>] [--support-url <support-url>] [--skip-whats-new] [--skip-promotional-text]

ARGUMENTS:
  <bundle-id>             The apps bundle id to translate the matadata for.

OPTIONS:
  --source-file <source-file>
                          The source '.json' file containing the base meta
                          data used for the translation.
  --source-language <source-language>
                          The source languate to translate from.
  --output-path <output-path>
                          The path to the folder where the '.json' files
                          should be saved.
  --marketing-url <marketing-url>
                          The marketing url.
  --support-url <support-url>
                          The support url.
  --skip-whats-new        Skip what's new.
  --skip-promotional-text Skip promotional text.
  -h, --help              Show help information.

```

# Output

The script outputs translated json files files for the meta data. The attributes equal the source file
