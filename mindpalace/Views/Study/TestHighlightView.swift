import SwiftUI
import Highlightr

struct TestHighlightView: View {
    let highlightr = Highlightr()!

    init() {
        highlightr.setTheme(to: "atom-one-dark")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Тест подсветки Highlightr")
                    .font(.title)
                    .padding()

                // Тест Java
                VStack(alignment: .leading) {
                    Text("JAVA")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let highlighted = highlightr.highlight(javaCode, as: "java") {
                        AttributedTextView(attributedString: highlighted)
                            .frame(height: 200)
                            .background(Color.gray.opacity(0.2))
                    } else {
                        Text("❌ Не удалось подсветить Java")
                    }
                }

                // Тест Swift
                VStack(alignment: .leading) {
                    Text("SWIFT")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let highlighted = highlightr.highlight(swiftCode, as: "swift") {
                        AttributedTextView(attributedString: highlighted)
                            .frame(height: 150)
                            .background(Color.gray.opacity(0.2))
                    } else {
                        Text("❌ Не удалось подсветить Swift")
                    }
                }

                // Тест Python
                VStack(alignment: .leading) {
                    Text("PYTHON")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let highlighted = highlightr.highlight(pythonCode, as: "python") {
                        AttributedTextView(attributedString: highlighted)
                            .frame(height: 100)
                            .background(Color.gray.opacity(0.2))
                    } else {
                        Text("❌ Не удалось подсветить Python")
                    }
                }
            }
            .padding()
        }
    }

    let javaCode = """
    public class HelloWorld {
        public static void main(String[] args) {
            System.out.println("Hello, World!");
            int number = 42;
        }
    }
    """

    let swiftCode = """
    struct User {
        let name: String
        var age: Int
    }
    """

    let pythonCode = """
    def greet(name):
        print(f"Hello, {name}!")
    """
}

struct AttributedTextView: UIViewRepresentable {
    let attributedString: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedString
    }
}

#Preview {
    TestHighlightView()
}
