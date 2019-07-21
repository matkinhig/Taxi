//
//  BaseViewController.swift
//  taxi-fare
//
//  Created by  Lực Nguyễn on 7/21/19.
//  Copyright © 2019 Nguyễn Lực. All rights reserved.
//

import UIKit

class BaseViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationController?.navigationBar.titleTextAttributes = [
        NSAttributedString.Key.font : UIFont(name: "Roboto-Medium", size: 17)!
    ]
  }
}
