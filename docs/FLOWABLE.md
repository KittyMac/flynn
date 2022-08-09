## Flowable Actors

Flowbale is a protocol for Actors included in Flynn. It defines a standard notation for chaining "arbitrary" actors together into simple networks of actors. This is extremely useful for data processing pipelines or node graphs of actors.

For example, lets suppose we were making a fully concurrent image processing pipeline. We create the following actors:

1. FindImages - finds all images in directory and sub-directories
1. LoadImageFromFile - reads an image (compressed) from disk
2. SaveImageToFile - saves an image (compressed) from disk
2. DecompressImage - takes compressed image data and decompresses it to RGB
2. CompressImage - takes image data and compresses it
3. BlackAndWhite - converts image data from RGB to Greyscale
4. GaussianBlur - performs a Gaussian blur on image data
5. Resize - resizes the image data
6. etc ...

Each actor adheres to the ```Flowable``` protocol. For this example, let's look at what the FindImages actor might look like:

```swift
class FindImages: Actor, Flowable {
    // input: path to source directory
    // output: paths to an individual image files
    public var safeFlowable = FlowableState()
    private let extensions: [String]

    init (_ extensions: [String]) {
        self.extensions = extensions
    }

    internal func _beFlow(_ args: FlowableArgs) {
        if args.isEmpty { return self.safeFlowToNextTarget(args) }

        let path: String = args[x:0]
        do {
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
            let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path),
                                                            includingPropertiesForKeys: resourceKeys,
                                                            options: [.skipsHiddenFiles],
                                                            errorHandler: { (url, error) -> Bool in
                                                                print("directoryEnumerator error at \(url): ", error)
                                                                return true
            })!

            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                let pathExtension = (fileURL.path as NSString).pathExtension
                if self.extensions.contains(pathExtension) && resourceValues.isDirectory == false {
                    self.safeFlowToNextTarget([fileURL.path])
                }
            }
        } catch {
            print(error)
        }
    }
}
```

A flowable actor really only needs to define on behavior, the ```beFlow()``` behavior.  This behavior receives data (in the form of the BehaviorArgs, which is [Any?]) and then passes data on to the next flowable target ( by calling ```self.safeFlowToNextTarget([fileURL.path])``` ). In our case, the FindImages actor expects to receive a file path to the directory to search for images, and for each image it finds it sends the path to that specific image to the next flowable actor.

Given this architecture and each of our actors implemented, we can then chain them together to form a pipeline where each piece of the pipeline processes concurrently to the other.

![](meta/flowable_graph.png)

This simple pipeline can then be instantiated and called like this:

```swift
let pipeline = FindImages(["png", "jpg", "pict"]) |>
                LoadImageFromFile() |>
                DecompressImage() |>
                BlackAndWhite() |>
                CompressImage() |>
                SaveImageToFile()

pipeline.beFlow(["path/to/images/folder1/"])
pipeline.beFlow(["path/to/images/folder2/"])
```
