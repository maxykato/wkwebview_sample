//
//  ViewController.swift
//  WKWebView
//
//  Created by 林　翼 on 2017/10/11.
//  Copyright © 2017年 Tsubasa Hayashi. All rights reserved.
//

import UIKit
import WebKit
import Kanna
import UIKit


let address = "http://news.livedoor.com/topics/detail/15972309/"

let pattern = "\\/pickup\\/\\d+$"

let titleXpathString = "/h1/a/p"

//あるサイトurlパターン一緒なのに、xpathのパターン複数がありますと。webview delegateをみると、結果0かどうか確認し、0だったら２番目のパターンを使う

let titleXpathString2 = "//h3"

let bodyXpathString = "//*[@id='article-detail']/div/div"

let bodyXpathString2 = "//*[@id='article-contents']/div[3]"



let isHeader = false //情報ヘッダから撮るか


class ViewController: UIViewController {
    
    var webView: WKWebView = WKWebView(frame: CGRect.zero)
    @IBOutlet weak var webViewContainer: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    @IBOutlet weak var bottomLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let regularExpression = try! NSRegularExpression(pattern: pattern)
        let match = regularExpression.firstMatch(in: address, range: NSRange(location: 0, length: address.count))
        print(match != nil)
        
        initializeWebView()
        let url = URL(string: address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
        webView.load(URLRequest(url: url))
        
    }
    
    @IBAction func onReloadButton(_ sender: UIBarButtonItem) {
        if webView.isLoading {
            webView.stopLoading()
        }
        webView.reload()
    }
    
    @IBAction func onTrashButton(_ sender: UIBarButtonItem) {
        let ac = UIAlertController(title: "Delete All Website Data", message: "DiskCache\nOfflineWebApplicationCache\nMemoryCache\nLocalStorage\nCookies\nSessionStorage\nIndexedDBDatabases\nWebSQLDatabases", preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default) { [weak self] (action) in
            self?.removeAllWKWebsiteData()
        }
        let cancel = UIAlertAction(title: "cancel", style: .cancel) { (action) in }
        ac.addAction(ok)
        ac.addAction(cancel)
        self.present(ac, animated: true, completion: nil)
    }
    
    
    private func initializeWebView() {
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        self.webViewContainer.addSubview(webView)
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        self.webViewContainer.addConstraints([
            NSLayoutConstraint(item: webView, attribute: .top, relatedBy: .equal, toItem: self.webViewContainer, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: webView, attribute: .left, relatedBy: .equal, toItem: self.webViewContainer, attribute: .left, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: webView, attribute: .right, relatedBy: .equal, toItem: self.webViewContainer, attribute: .right, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: webView, attribute: .bottom, relatedBy: .equal, toItem: self.webViewContainer, attribute: .bottom, multiplier: 1, constant: 0)
            ])
    }
    
    fileprivate func removeAllWKWebsiteData() {
        let websiteDataTypes = Set([
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeOfflineWebApplicationCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeIndexedDBDatabases,
            WKWebsiteDataTypeWebSQLDatabases
            ])
        
        WKWebsiteDataStore
            .default()
            .removeData(
                ofTypes: websiteDataTypes,
                modifiedSince: Date(timeIntervalSince1970: 0),
                completionHandler: {}
        )
    }
}

// MARK: WebViewDelegate
extension ViewController: WKUIDelegate, WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Benchmarks.shared.start(key: webView.url?.absoluteString ?? "")
        indicatorView.startAnimating()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let time = Benchmarks.shared.finish(key: webView.url?.absoluteString ?? "")
        bottomLabel.text = time
        textField.text = webView.url?.absoluteString ?? ""
        indicatorView.stopAnimating()
        textField.resignFirstResponder()
        
        /*
            この辺から抽出のところとなっている。DispatchQueue.main.asyncAfterはあるサイトreactiveで、情報はすぐ取れないと言う訳です。
        */
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            webView.evaluateJavaScript("document.documentElement.innerHTML",
                                       completionHandler: { (html, _) -> Void in
                                        guard let htmlString = html as? String else { return }
                                        
                                        print("ran")
                                        
                                        do {
                                            var doc: HTMLDocument
                                            try doc = HTML(html: htmlString, encoding: String.Encoding.utf8)
                                            var parentNode: XMLElement? = nil
                                            
                                            if(isHeader){
                                                parentNode = doc.head
                                            } else {
                                                parentNode = doc.body
                                            }
                                            
                                            
                                            var titleNodes = parentNode?.xpath(titleXpathString)
                                            if(titleNodes?.count == 0) {
                                                titleNodes = parentNode?.xpath(titleXpathString2)
                                            }
                                            for node in titleNodes! {
                                                print(node.content)
                                            }
                                            
                                            var contentNodes = parentNode?.xpath(bodyXpathString)
                                            if(contentNodes?.count == 0) {
                                                contentNodes = parentNode?.xpath(bodyXpathString2)
                                            }
                                            for node in contentNodes! {
                                                print(node.content)
                                            }
                                            
                                        } catch let error {
                                            print(error)
                                        }
            }
            )

        }
        
        
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        indicatorView.stopAnimating()
    }
}

// MARK: UITextFieldDelegate
extension ViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text, !text.isEmpty else {
            let ac = UIAlertController.makeSimpleAlert("TextField is empty", message: nil, okTitle: "OK", okAction: nil, cancelTitle: nil, cancelAction: nil)
            self.present(ac, animated: true, completion: nil)
            return true
        }
        
        guard let url = URL(string: text), UIApplication.shared.canOpenURL(url) else {
            let ac = UIAlertController.makeSimpleAlert("Text is not URL", message: nil, okTitle: "OK", okAction: nil, cancelTitle: nil, cancelAction: nil)
            self.present(ac, animated: true, completion: nil)
            return true
        }
        
        webView.load(URLRequest(url: url))
        textField.resignFirstResponder()
        return true
    }
    
}

// MARK: extension UIAlertController
extension UIAlertController {
    /// Create simple alert with OK, Cancel
    static internal func makeSimpleAlert(_ title: String?, message: String?, okTitle: String?, okAction: ((UIAlertAction) -> Void)? ,cancelTitle: String?, cancelAction: ((UIAlertAction) -> Void)?) -> UIAlertController {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        // OK
        if let okTitle = okTitle {
            let okAction = UIAlertAction(title: okTitle, style: .default, handler: okAction)
            alertController.addAction(okAction)
        }
        // Cancel
        if let cancelTitle = cancelTitle {
            let cancelAction = UIAlertAction(title: cancelTitle, style: .default, handler: cancelAction)
            alertController.addAction(cancelAction)
        }
        
        return alertController
    }
}
