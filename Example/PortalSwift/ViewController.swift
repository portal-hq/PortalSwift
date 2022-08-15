//
//  ViewController.swift
//  PortalSwift
//
//  Created by Blake Williams on 08/14/2022.
//  Copyright (c) 2022 Blake Williams. All rights reserved.
//

import UIKit
import PortalSwift

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
      
      let request = HttpRequest<String, [String: String]>(
        url: "https://portalhq.io/",
        method: "GET",
        body: [:],
        headers: [:]
      )
      
      do {
        let _ = try request.send() { (response: String) in
          print(response)
        }
      } catch let error {
        print(error)
      }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

