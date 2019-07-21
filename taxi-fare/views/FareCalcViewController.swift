//
//  ViewController.swift
//  taxi-fare
//
//  Created by  Lực Nguyễn on 7/21/19.
//  Copyright © 2019 Nguyễn Lực. All rights reserved.
//

import UIKit
import MapKit
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


class FareCalcViewController: BaseViewController, UITextFieldDelegate, CLLocationManagerDelegate {
  @IBOutlet weak var _txtFrom: UITextField!
  @IBOutlet weak var _txtTo: UITextField!
  @IBOutlet weak var _lblEstimatedFare: UILabel!
  
  // Hoan Kiem Lake coordinate: 21.0287542 - 105.8523605
  fileprivate let _locationManager = CLLocationManager()
  fileprivate var _currentLocation: CLLocation?
  fileprivate var _fromLocation: MKMapItem?
  fileprivate var _toLocation: MKMapItem?
  fileprivate var _possibleRoutes: [MKRoute]?
  fileprivate var _btnCurrentLocationTouchedUp: Bool = false
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Setup location manager
    _locationManager.delegate = self
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest
    _locationManager.requestWhenInUseAuthorization()
  }
  
  override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
    if _possibleRoutes?.count == 0 && _fromLocation != nil && _toLocation != nil {
      self.findRoutes()
    }
    
    // Not showing map if there's no possible routes
    return _fromLocation != nil && _toLocation != nil && _possibleRoutes?.count > 0
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    let mapVC = segue.destination as! MapViewController
    mapVC.displayingRoutes = _possibleRoutes!
    mapVC.fromLocation = _fromLocation!
    mapVC.toLocation = _toLocation!
  }
  
  // Button callbacks
  @IBAction func btnCurrentLocationTouchedUpInside(_ sender: UIButton) {
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    _locationManager.requestLocation()
  }
  
  @IBAction func btnCalcFareTouchedUpInside(_ sender: UIButton) {
    self.validateAndFindRoutes()
  }
  
  // UITextFieldDelegate methods
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if (textField.text?.count == 0) {
      return false
    }
    
    if textField === _txtFrom {
      _txtTo.becomeFirstResponder()
    } else {
      textField.resignFirstResponder()
    }
    
    return true
  }
  
  func textFieldDidEndEditing(_ textField: UITextField) {
    self.searchLocation(keyword: textField.text) { [weak self] (mapItem) in
      self?.updateLocationName(withItem: mapItem, toTextField: textField)
    }
  }
  
  // CLLocationManagerDelegate methods
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    if status == .authorizedWhenInUse {
      _locationManager.requestLocation()
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    UIApplication.shared.isNetworkActivityIndicatorVisible = false
    
    if let location = locations.first {
      _currentLocation = location
      self.updateCurrentLocationName()
    }
  }
  
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    UIApplication.shared.isNetworkActivityIndicatorVisible = false
    print(error)
  }
  
  // Custom functions
  func searchLocation(keyword searchKey: String?, completion handler: @escaping (MKMapItem) -> Void) {
    if _currentLocation == nil || searchKey == nil {
      return
    }
    
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = searchKey
    
    let searchResult = MKLocalSearch(request: request)
    searchResult.start { (response, _) in
      UIApplication.shared.isNetworkActivityIndicatorVisible = false
      
      if response == nil || response!.mapItems.isEmpty {
        return
      }
      
      handler(response!.mapItems.first!)
    }
  }
  
  func updateLocationName(withItem mapItem: MKMapItem, toTextField textField: UITextField) {
    let placemark = mapItem.placemark as CLPlacemark
    textField.text = self.addressNameFromPlacemark(placemark)
    
    if textField === _txtFrom {
      _fromLocation = mapItem
    } else {
      _toLocation = mapItem
    }
  }
  
  func updateCurrentLocationName() {
    let geoCoder = CLGeocoder()
    geoCoder.reverseGeocodeLocation(_currentLocation!) { [weak self] (placemarks, _) in
      if placemarks == nil || placemarks?.count == 0 {
        return
      }
      
      let placemark = placemarks!.first! as CLPlacemark
      self?._fromLocation = MKMapItem(placemark: MKPlacemark(placemark: placemark))
      self?._txtFrom.text = self?.addressNameFromPlacemark(placemark)
    }
  }
  
  func validateAndFindRoutes() {
    if _fromLocation == nil {
      _txtFrom.becomeFirstResponder()
      return
    }
    
    if _toLocation == nil {
      _txtTo.becomeFirstResponder()
      return
    }
    
    _txtFrom.resignFirstResponder()
    _txtTo.resignFirstResponder()
    
    self.findRoutes()
  }
  
  func findRoutes() {
    let request = MKDirections.Request()
    request.source = _fromLocation
    request.destination = _toLocation
    request.requestsAlternateRoutes = true
    request.transportType = .automobile
    
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
    
    let directions = MKDirections(request: request)
    directions.calculate { [weak self] (response, error) in
      UIApplication.shared.isNetworkActivityIndicatorVisible = false
      
      if error != nil {
        print(error ?? "error!")
        return
      }
      
      if let routes = response?.routes {
        self?.calculateAndDisplayEstimatedFares(orderedRoutes: routes)
      }
    }
  }
  
  func calculateAndDisplayEstimatedFares(orderedRoutes routes: [MKRoute]) {
    _possibleRoutes = routes.sorted { $0.distance < $1.distance }
    let (minFare, maxFare) = self.calculateFare(fromRoutes: _possibleRoutes!)
    
    let numberFormatter: NumberFormatter = {
      let formattedNumber = NumberFormatter()
      formattedNumber.numberStyle = .decimal
      formattedNumber.maximumFractionDigits = 0
      formattedNumber.locale = Locale(identifier: "vi-VN")
      return formattedNumber
    }()

    var formattedFares = [numberFormatter.string(from: NSNumber(value: minFare))!]
    if maxFare > 0 {
      formattedFares.append(numberFormatter.string(from: NSNumber(value: maxFare))!)
    }
    
    _lblEstimatedFare.text = "\(formattedFares.joined(separator: " - ")) VNĐ"
  }
  
  func calculateFare(fromRoutes orderedRoutes: [MKRoute]) -> (Int, Int) {
    // If there's only one route
    if orderedRoutes.count == 1 {
      return (self.taxiFare(forDistance: orderedRoutes.first!.distance), -1)
    }
    
    // Multiple routes
    return (
      self.taxiFare(forDistance: orderedRoutes.first!.distance),
      self.taxiFare(forDistance: orderedRoutes.last!.distance)
    )
  }
  
  func addressNameFromPlacemark(_ placemark: CLPlacemark) -> String {
    let addresses = placemark.addressDictionary!
    let addressLines: [String] = [
      addresses["Name"] as! String,
      addresses["City"] as! String,
      addresses["Country"] as! String
    ]
    return addressLines.joined(separator: ", ")
  }
  
  func taxiFare(forDistance distance: Double) -> Int {
    // First 0.3 km costs 10.000 VND
    let openDoorFare = 10.0
    var nextKmsFare = 0.0
    let longDistance = 33000.0
    var longDistanceFare = 0.0
    
    // Next kms
    if distance - 300 > 0 {
      // From 33th km, cost is 11.000 VND per km
      if distance > longDistance {
        nextKmsFare = (longDistance - 300) / 1000 * 13.9
        longDistanceFare = (distance - longDistance) / 1000 * 11
      } else {
        // Next kms till 33th km cost 13.900 VND per km
        nextKmsFare = (distance - 300) / 1000 * 13.9
      }
    }
    
    let ceiling = ceil(openDoorFare + nextKmsFare + longDistanceFare)
    return Int(ceiling)*1000
  }
}

