//
//  MapViewController.swift
//  taxi-fare
//
//  Created by  Lực Nguyễn on 7/21/19.
//  Copyright © 2019 Nguyễn Lực. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: BaseViewController, MKMapViewDelegate {
  @IBOutlet weak var _vMap: MKMapView!
  
  // Possible routes calculated from FareCalcViewController
  var displayingRoutes: [MKRoute]!
  var fromLocation: MKMapItem!
  var toLocation: MKMapItem!
  
  override func viewDidLoad() {
    super.viewDidLoad()

    self.pinAnnotations()
    
    // Best route is rendered last to be on-top
    for route in self.displayingRoutes.reversed() {
      self.plotPolyline(route)
    }
  }
  
  // MKMapViewDelegate methods
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    let polylineRenderer = MKPolylineRenderer(overlay: overlay)
    
    if overlay is MKPolyline {
      // Default color
      var strokeColor = UIColor.blue
      
      if mapView.overlays.count == self.displayingRoutes.count {
        strokeColor = UIColor(red: 0, green: 179.0/255, blue: 253.0/255, alpha: 1)
      } else {
        strokeColor = UIColor(red: 175.0/255, green: 175.0/255, blue: 175.0/255, alpha: 1)
      }
      
      polylineRenderer.strokeColor = strokeColor
      polylineRenderer.lineWidth = 5
    }
    
    return polylineRenderer
  }
  
  func pinAnnotations() {
    for location in [self.fromLocation, self.toLocation] {
      let annotation = MKPointAnnotation()
      
      annotation.coordinate = (location?.placemark.coordinate)!
      annotation.title = location?.placemark.name
      annotation.subtitle = location?.placemark.locality
      
      _vMap.addAnnotation(annotation)
    }
  }
  
  func plotPolyline(_ route: MKRoute) {
    _vMap.addOverlay(route.polyline)
    
    let edgePadding = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
    var mapRect: MKMapRect

    if _vMap.overlays.count == self.displayingRoutes.count {
      mapRect = _vMap.visibleMapRect.union(route.polyline.boundingMapRect)
    } else {
      mapRect = route.polyline.boundingMapRect
    }
    
    _vMap.setVisibleMapRect(mapRect, edgePadding: edgePadding, animated: true)
  }
}
