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
import RealmSwift

var address = "https://headlines.yahoo.co.jp/hl?a=20190204-35132229-cnetj-sci"
var titleXpathString = "//meta[@property='og:description']"

/*
 あるサイトurlパターン一緒なのに、xpathのパターン複数がありますと。webview delegateをみると、結果0かどうか確認し、0だったら２番目のパターンを使う
 */

let titleXpathString2 = "//div[1]/div[@class='mnr-c xpd O9g5cc uUPGi' and 1]/div[@class='U3THc' and 1]/div[1]/div[1]/a[@class='C8nzq BmP5tf' and 1]/div[@class='MUxGbd v0nnCb' and 1]"
var bodyXpathString = "//div[@class='headlineText']/p[1]"
let isHeader = false //情報ヘッダから撮るか


class TextExtractResult: Object {
    dynamic var id = 0
    dynamic var title = ""
    dynamic var content = ""
}






class ViewController: UIViewController {
    
    var webView: WKWebView = WKWebView(frame: CGRect.zero)
    @IBOutlet weak var webViewContainer: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    @IBOutlet weak var bottomLabel: UILabel!
    var csvArr: [String] = []
    var i = 1
    var csvArr2: [[String]] = []
    var titleString  = ""
    var content = ""
    var id = 0
    let realm = try! Realm()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeWebView()
        if let csvPath = Bundle.main.path(forResource: "xpathList", ofType: "tsv") {
            do {
                let csvStr = try String(contentsOfFile: csvPath, encoding: String.Encoding.utf8)
                csvArr = csvStr.components(separatedBy: "\n")
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
        
        for data in csvArr {
            print(data)
            let splitedData = data.components(separatedBy: "\t")
            csvArr2.append(splitedData)
        }
        
        address = csvArr2[i][2]
        titleXpathString = csvArr2[i][6]
        bodyXpathString = csvArr2[i][8]
        //
        //
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
                                            
                                            self.titleString = ""
                                            self.content = ""
                                            for node in titleNodes! {
                                                print("title:" + node.content!)
                                                self.titleString += node.content!
                                            }
                                            
                                            let contentNodes = parentNode?.xpath(bodyXpathString)
                                            for node in contentNodes! {
                                                print("content:" + node.content!)
                                                self.content += node.content!
                                            }
                                            
                                            let data = TextExtractResult()
                                            data.title = self.titleString
                                            data.content = self.content
                                            data.id = Int(self.csvArr2[self.i][0])!
                                            
                                            try! self.realm.write {
                                                self.realm.add(data)
                                            }
                                            
                                            guard self.i < 36 else {
                                                print("done")
                                                return
                                            }
                                            self.i += 1
                                            address = self.csvArr2[self.i][2]
                                            
                                            titleXpathString = self.csvArr2[self.i][6]
                                            bodyXpathString = self.csvArr2[self.i][8]
                                            
                                            
                                            let url = URL(string: address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
                                            webView.load(URLRequest(url: url))
                                            
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
