import SwiftUI
import UIKit

/// Texto justificado com hifenização. O `Text` do SwiftUI não oferece alinhamento justificado.
struct JustifiedText: UIViewRepresentable {
    let text: String
    var textStyle: UIFont.TextStyle = .caption1
    var color: Color = .appSecondaryText

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .justified
        paragraph.hyphenationFactor = 1
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: textStyle),
                .foregroundColor: UIColor(color),
                .paragraphStyle: paragraph,
            ]
        )
        label.accessibilityLabel = text
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView label: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIView.layoutFittingExpandedSize.width
        let size = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }
}
