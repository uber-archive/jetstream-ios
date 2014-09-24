//
//  ViewController.swift
//  JetstreamDemos
//
//  Created by Rob Skillington on 9/23/14.
//  Copyright (c) 2014 Uber Technologies, Inc. All rights reserved.
//

import UIKit

class DemosListViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    enum Demo {
        case ShapesDemo
    }

    private var demos: [(Demo, String)] = [(.ShapesDemo, "Drag shapes")]

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.demos.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let reuseIdentifier = "DemosListCollectionViewCell"
        var demo = self.demos[indexPath.row]
        var cell: DemosListCollectionViewCell
        cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as DemosListCollectionViewCell
        cell.titleLabel.text = demo.1;
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        var demo = self.demos[indexPath.row]
        switch demo.0 {
        case .ShapesDemo:
            self.performSegueWithIdentifier("ShapesDemoSegue", sender: self)
        }
    }

}
