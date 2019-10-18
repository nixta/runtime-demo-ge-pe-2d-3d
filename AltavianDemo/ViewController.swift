// Copyright 2019 Esri.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ArcGIS

let inBufferFieldName = "inBuffer"

class ViewController: UIViewController {

    @IBOutlet weak var mapView: AGSMapView!
    @IBOutlet weak var addGraphicsButton: UIButton!
    @IBOutlet weak var feedbackLabel: UILabel!
    @IBOutlet weak var insideBufferLabel: UILabel!
    @IBOutlet weak var outsideBufferLabel: UILabel!
    
    @IBOutlet weak var latLonLabel: UILabel!
    @IBOutlet weak var utmLabel: UILabel!
    @IBOutlet weak var latLongDMSLabel: UILabel!
    @IBOutlet weak var mgrsLabel: UILabel!
    
    var bufferSize: Double = 0.5
    
    /// Define a Graphics Overlay for ephemeral graphics which we will animate and display according to whether they're within a polygon.
    let overlay: AGSGraphicsOverlay = {
        // Define a default symbol (in this case it'll be used when the graphic is not within the polygon)
        let symbol = AGSSimpleMarkerSymbol(style: .circle, color: .red, size: 20)
        
        // Define a symbol to be used when the graphic is within the polygon.
        let inBufferSymbol = AGSSimpleMarkerSymbol(style: .circle, color: .green, size: 10)
        
        // Define a rule for the unique value renderer to use to draw these contained graphics differently.
        // In this case we'll match graphics with the key/value "attribute" for "inBuffer" set to 1.
        let inBufferUniqueValue = AGSUniqueValue(description: "In the buffer", label: "In Buffer", symbol: inBufferSymbol, values: [1])
        
        // Set up a unique value renderer with the above rule.
        let uvr = AGSUniqueValueRenderer(fieldNames: [inBufferFieldName],
                                         uniqueValues: [inBufferUniqueValue],
                                         defaultLabel: "Outside buffer",
                                         defaultSymbol: symbol)
        
        // Create a Graphics Overlay that uses the above renderer. As we modify graphics, the renderer will notice the
        // modifications and automatically update the way the graphics are displayed on the map.
        let overlay = AGSGraphicsOverlay()
        overlay.renderer = uvr
        
        return overlay
    }()
    
    let bufferOverlay = AGSGraphicsOverlay()
    
    var animationTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // Initialize the map "model".
        let map = AGSMap(basemapType: .imageryWithLabelsVector, latitude: 40.7128, longitude: -74.0060, levelOfDetail: 15)
        
        // Set the map view UI control to use this map.
        mapView.map = map

        // Add some overlays for the demo. One to show the moving graphic dots, and one to show the buffer.
        mapView.graphicsOverlays.add(overlay)
        mapView.graphicsOverlays.add(bufferOverlay)
        
        // Configure our app to handle UI interaction events
        mapView.touchDelegate = self
        
        // Turn off an optional map view element (it gets in the way of this demo).
        mapView.interactionOptions.isMagnifierEnabled = false
    }
    
    @IBAction func addGraphics(_ sender: Any) {
        addGraphics(count: 100)
    }
    
    @IBAction func clearGraphics(_ sender: Any) {
        clearGraphics()
    }
    
    @IBAction func clearBuffer(_ sender: Any) {
        (bufferOverlay.graphics.firstObject as? AGSGraphic)?.geometry = nil
        updateGraphicsForBuffer()
        bufferOverlay.graphics.removeAllObjects()
        insideBufferLabel.text = "No Buffer"
        outsideBufferLabel.text = "No Buffer"
    }
}

extension ViewController {
    /// Coordinate conversion
    func showFormattedCoordinates(for mapPoint: AGSPoint) {
        latLonLabel.text = AGSCoordinateFormatter.latitudeLongitudeString(from: mapPoint, format: .decimalDegrees, decimalPlaces: 4)
        latLongDMSLabel.text = AGSCoordinateFormatter.latitudeLongitudeString(from: mapPoint, format: .degreesMinutesSeconds, decimalPlaces: 1)
        utmLabel.text = AGSCoordinateFormatter.utmString(from: mapPoint, conversionMode: .latitudeBandIndicators, addSpaces: true)
        mgrsLabel.text = AGSCoordinateFormatter.mgrsString(from: mapPoint, conversionMode: .automatic, precision: 4, addSpaces: true)
    }

    /// Buffer creation
    func getBufferGeometryFor(mapPoint: AGSPoint) -> AGSPolygon? {
        guard let extent = mapView.currentViewpoint(with: .boundingGeometry)?.targetGeometry as? AGSEnvelope,
            let webMercatorExtent = AGSGeometryEngine.projectGeometry(extent, to: AGSSpatialReference.webMercator()) as? AGSEnvelope else { return nil }

        let unit = webMercatorExtent.spatialReference?.unit as? AGSLinearUnit ?? AGSLinearUnit.meters()
        let size = min(webMercatorExtent.width, webMercatorExtent.height) * bufferSize / 2

        return AGSGeometryEngine.geodeticBufferGeometry(mapPoint, distance: size, distanceUnit: unit,
                                                        maxDeviation: Double.nan, curveType: .shapePreserving)
    }

    /// Point in polygon
    func isGraphicInBuffer(graphic: AGSGraphic) -> Bool {
        guard let buffer = bufferOverlay.graphics.firstObject as? AGSGraphic,
            let bufferGeometry = buffer.geometry as? AGSPolygon,
            let graphicGeometry = graphic.geometry else { return false }
        
        return AGSGeometryEngine.geometry(bufferGeometry, contains: graphicGeometry)
    }
}

/// User interaction
extension ViewController: AGSGeoViewTouchDelegate {
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        // Clear the buffer overlay layer. We'll create a new buffer below.
        bufferOverlay.graphics.removeAllObjects()
        
        // Get the geodesic buffer based off the tapped position on the map.
        let bufferGeometry = getBufferGeometryFor(mapPoint: mapPoint)
        
        // Create a graphic for the buffer, including a semi-transparent fill symbol with a solid edge
        // Note that in this case we put the symbol on the graphic rather than defining a renderer.
        let fillSymbol = AGSSimpleFillSymbol(style: .solid,
                                             color: UIColor.orange.withAlphaComponent(0.5),
                                             outline: AGSSimpleLineSymbol(style: .solid, color: UIColor.orange, width: 8))
        let graphic = AGSGraphic(geometry: bufferGeometry, symbol: fillSymbol, attributes: nil)
        bufferOverlay.graphics.add(graphic)

        // And let's update the coordinate display for the tapped point
        showFormattedCoordinates(for: mapPoint)
    }
    
    func geoView(_ geoView: AGSGeoView, didMoveLongPressToScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        // Much as with the tap, we'll just update the buffer (no need to create a new graphic).
        guard let bufferGraphic = bufferOverlay.graphics.firstObject as? AGSGraphic else { return }
        
        // Update the graphic with a new geometry. Runtime will take care of updating the rendering.
        bufferGraphic.geometry = getBufferGeometryFor(mapPoint: mapPoint)
                
        // And let's update the coordinate display for the point the user has dragged to.
        showFormattedCoordinates(for: mapPoint)
    }
}

/// Update graphic attribution
extension ViewController {
    func updateGraphicsForBuffer() {
        // This method will update the key/value attribution on each graphic that is used by the Unique Value Renderer.
        // The attribution is set depending on whether the geometry is within the current buffer.
        guard bufferOverlay.graphics.count > 0 else { return }
        
        var insideBufferCount = 0
        var outsideBufferCount = 0
        
        for graphic in overlay.graphics as! [AGSGraphic] {
            let isWithinBuffer = isGraphicInBuffer(graphic: graphic)
            graphic.attributes[inBufferFieldName] = isWithinBuffer ? 1 : 0
            if isWithinBuffer {
                insideBufferCount += 1
            } else {
                outsideBufferCount += 1
            }
        }
        
        // Update the UI labels
        insideBufferLabel.text = "\(insideBufferCount) inside"
        outsideBufferLabel.text = "\(outsideBufferCount) outside"
    }
}

/// Graphics Management
extension ViewController {
    /// Create a randomly placed graphic within the current map view, and assign a random speed.
    func makeGraphic(withSpeed speed: Double) -> AGSGraphic {
        let screenPoint = getRandomCoordinate(within: mapView.bounds)
        let mapPoint = mapView.screen(toLocation: screenPoint)
        let heading = Int.random(in: 1...360).degreesToRadians
        let dx = sin(heading) * CGFloat(speed)
        let dy = cos(heading) * CGFloat(speed)
        let graphic = AGSGraphic(geometry: mapPoint, symbol: nil, attributes:   ["dx": dx, "dy": dy, inBufferFieldName: 0])
        return graphic
    }
    
    /// Add a number of random graphics
    func addGraphics(count: Int) {
        let viewPoint = mapView.currentViewpoint(with: .boundingGeometry)
        guard let extent = viewPoint?.targetGeometry as? AGSEnvelope else {
            print("Could not get a viewpoint extent!")
            return
        }
        
        for _ in 1...count {
            let graphic = makeGraphic(withSpeed: Double.random(in: (extent.width/1000)...(extent.width/500)))
            overlay.graphics.add(graphic)
        }
        
        // Kick off the animation timer to make the graphics move around…
        if animationTimer == nil {
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1/30,
                                                  repeats: true,
                                                  block: { [weak self] timer in
                self?.moveGraphics()
                self?.updateGraphicsForBuffer()
            })
        }
        
        feedbackLabel.text = "\(overlay.graphics.count) graphics"
    }

    func clearGraphics() {
        animationTimer?.invalidate()
        animationTimer = nil

        overlay.graphics.removeAllObjects()

        feedbackLabel.text = "No graphics"
        insideBufferLabel.text = "No graphics"
        outsideBufferLabel.text = "No graphics"
    }
    
    func moveGraphics() {
        guard let extent = mapView.currentViewpoint(with: .boundingGeometry)?.targetGeometry as? AGSEnvelope else {
            print("Could not get a viewpoint extent!")
            return
        }
        
        for graphic in overlay.graphics as! [AGSGraphic] {
            moveGraphic(graphic: graphic, within: extent)
        }
    }
    
    func moveGraphic(graphic: AGSGraphic, within extent: AGSEnvelope) {
        guard let dx = graphic.attributes["dx"] as? Double,
            let dy = graphic.attributes["dy"] as? Double else {
                print("Graphic has no velocity information!")
                return
        }
        
        guard let builder = graphic.geometry?.toBuilder() as? AGSPointBuilder else { return }
        
        builder.offsetBy(x: dx, y: dy)
        
        if builder.x > extent.xMax || builder.x < extent.xMin {
            graphic.attributes["dx"] = -dx
        }
        if builder.y > extent.yMax || builder.y < extent.yMin {
            graphic.attributes["dy"] = -dy
        }

        graphic.geometry = builder.toGeometry()
    }
    
    func getRandomCoordinate(within bounds: CGRect) -> CGPoint {
        let x = bounds.minX + CGFloat.random(in: 0...bounds.width)
        let y = bounds.minY + CGFloat.random(in: 0...bounds.height)
        return CGPoint(x: x, y: y)
    }
}

extension BinaryInteger {
    var degreesToRadians: CGFloat { return CGFloat(self) * .pi / 180 }
}

extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}
