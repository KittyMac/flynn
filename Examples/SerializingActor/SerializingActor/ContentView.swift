// An example of how one might create a data storage Actor using Flynn. Changes
// to the actor can happen concurrently, and updates are passed on to SwiftUI
// on the main thread

// swiftlint:disable line_length

import SwiftUI
import Flynn

struct ContentView: View {
    @ObservedObject
    private var model = ConcurrentData()

    init(_ model: ConcurrentData) {
        self.model = model
    }

    var body: some View {
        VStack(alignment: .center) {
            HStack(alignment: .center) {
                Text("Count:")
                    .font(.callout)
                    .bold()
                TextField("Enter username...", text: $model.unsafeCount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }.padding()

            Text("Our data model is a Flynn actor; this allows it to manipulate the data in a concurrency safe manner. Use the text field to change the value of the counter, the model actor will increment the value by one every half second.")
            .font(.callout)
            .padding()

        }.padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var model = ConcurrentData()
    static var previews: some View {
        ContentView(ContentView_Previews.model)
    }
}
