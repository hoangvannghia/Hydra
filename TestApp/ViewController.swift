//
//  ViewController.swift
//  TestApp
//
//  Created by danielemargutti on 08/01/2018.
//  Copyright © 2018 Hydra. All rights reserved.
//

import UIKit

public enum TestErrors: Error{
	case timeout
	case other
	case failed
}

class ViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		
//		let url = URL(string: "https://cdn.vox-cdn.com/thumbor/Pkmq1nm3skO0-j693JTMd7RL0Zk=/0x0:2012x1341/1200x800/filters:focal(0x0:2012x1341)/cdn.vox-cdn.com/uploads/chorus_image/image/47070706/google2.0.0.jpg")!
//		self.download(url: url).then
		
		let subj = Subject<Int,NoError>()
		subj.on { event in
			print("received")
			return NotDisposable
		}
		subj.send(5)
		
	}
	
//	func download(url: URL) -> Promise<UIImage?,TestErrors> {
//		return Promise<UIImage?,TestErrors>({ r, rj,s  in
//			URLSession.shared.dataTask(with: url) { data, response, error in
//				if let _ = error {
//					rj(TestErrors.failed)
//				} else {
//					if let d = data {
//						let img = UIImage(data: d)
//						r(img)
//					} else {
//						r(nil)
//					}
//				}
//			}.resume()
//		})
//	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	
}

