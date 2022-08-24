//
//  ViewController.swift
//  DiscoGlobe
//
//  Created by Daniel Eke on 24.8.2022.
//

import UIKit
import MapboxMaps
import AudioKit
import AudioKitEX

private class Constants {
    // The number of frequency bands we use for the visuals.
    // This value is also used for the number of unique layers used on the map
    // which are representing the height of each frequency based
    // on their relative strength.
    static let FrequencySplit = 16
    static let FftSize = 512
    static let SampleCount: Int = FftSize / FrequencySplit
    // The list of postal codes of countries are used to randomize the filters of the layers
    static let CountryCodes = [
        "A", "AE", "AF", "AL", "AO", "AR", "ARM", "AU", "AZ", "B", "BD", "BF",
        "BG", "BI", "BiH", "BJ", "BN", "BO", "BR", "BS", "BT", "BW", "BY",
        "BZ", "CA", "CF", "CG", "CH", "CI", "CL", "CM", "CN", "CO", "CR", "CU",
        "CY", "CZ", "D", "DJ", "DK", "DO", "DRC", "DZ", "E", "EC", "EG", "ER",
        "ES", "EST", "ET", "F", "FIN", "FJ", "FK", "GA", "GB", "GE", "GH",
        "GL", "GM", "GN", "GQ", "GR", "GT", "GW", "GY", "HN", "HR", "HT", "HU",
        "I", "IND", "IRL", "IRN", "IRQ", "IS", "J", "KE", "KG", "KH", "KO",
        "KP", "KR", "KW", "KZ", "L", "LA", "LB", "LK", "LR", "LS", "LT", "LV",
        "LY", "MA", "MD", "ME", "MG", "ML", "MM", "MN", "MR", "MW", "MX", "MY",
        "MZ", "N", "NA", "NC", "NE", "NG", "NI", "NL", "NM", "NP", "NZ", "OM",
        "P", "PA", "PAL", "PE", "PG", "PH", "PK", "PL", "PR", "PY", "QA", "RO",
        "RS", "RUS", "RW", "S", "SA", "SB", "SD", "SK", "SL", "SLO", "SN",
        "SO", "SR", "SS", "SV", "SYR", "TD", "TG", "TH", "TJ", "TL", "TM",
        "TN", "TR", "TT", "TW", "TZ", "UA", "UG", "US", "UY", "UZ", "VE",
        "VN", "VU", "WS", "YE", "ZA", "ZM", "ZW"
    ]
}

class ViewController: UIViewController {

    private var mapView: MapView!
    private var colorSwitchTimer = Timer()
    private var globeRotateTimer = Timer()
    private var audioFeatureUpdateTimer = Timer()
    private let globeRotateInterval = 3.0
    private let audioAnalyzer = AudioAnalyzer()

    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true

        let cameraOptions = CameraOptions(
            center: CLLocationCoordinate2D(latitude: 30.0, longitude: 0.0),
            zoom: 2.0, bearing: -20.0, pitch: 20.0
        )
        let options = MapInitOptions(cameraOptions: cameraOptions, styleURI: .none)
        mapView = MapView(frame: view.bounds, mapInitOptions: options)

        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(mapView)
        mapView.ornaments.scaleBarView.isHidden = true
        mapView.ornaments.compassView.isHidden = true
        mapView.mapboxMap.style.JSON = StyleProvider().createStyle()
        try? mapView.mapboxMap.style.setProjection(.init(name: .globe))
        try? mapView.mapboxMap.style.setAtmosphere(Atmosphere())
        try? mapView.mapboxMap.style.setAtmosphereProperty("high-color", value: "rgba(255, 100, 255, 1.0)")
        try? mapView.mapboxMap.style.setAtmosphereProperty("space-color", value: "rgba(60, 60, 155, 1.0)")
        try? mapView.mapboxMap.style.setAtmosphereProperty("horizon-blend", value: 0.1)

        colorSwitchTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            self?.updateColors()
        })

        globeRotateTimer = Timer.scheduledTimer(withTimeInterval: globeRotateInterval, repeats: true, block: { [weak self] _ in
            self?.rotateGlobe()
        })

        audioFeatureUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true, block: { [weak self] _ in
            self?.updateAudioFeatures()
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        rotateGlobe()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    private func updateColors() {
        let randomInt = Int.random(in: 0..<Constants.FrequencySplit)
        try? mapView.mapboxMap.style.updateLayer(withId: "countries-\(randomInt)", type: FillExtrusionLayer.self) { layer in
            layer.fillExtrusionColor = .constant(StyleColor.init(UIColor.random))
        }
        try? mapView.mapboxMap.style.updateLayer(withId: "columns-\(randomInt)", type: FillLayer.self) { layer in
            layer.fillColor = .constant(StyleColor.init(UIColor.random))
        }
        try? mapView.mapboxMap.style.setAtmosphereProperty("high-color", value: UIColor.random.toRgbaString())
    }

    private func rotateGlobe() {
        mapView.camera.fly(to: CameraOptions(
                center: CLLocationCoordinate2D(latitude: 30.0, longitude: mapView.mapboxMap.cameraState.center.longitude + 20.0)
        ), duration: globeRotateInterval)
    }

    private func updateAudioFeatures() {
        try? mapView.mapboxMap.style.setAtmosphereProperty("star-intensity", value: 0.5 + Double(audioAnalyzer.globalAmp))
        for index in 0..<Constants.FrequencySplit {
            try? mapView.mapboxMap.style.updateLayer(withId: "countries-\(index)", type: FillExtrusionLayer.self) { layer in
                layer.fillExtrusionHeight = .constant(1000.0 + audioAnalyzer.amps[index] * audioAnalyzer.globalAmp * 1000000.0)
            }
        }
    }

}

private class StyleProvider {
    
    func createStyle() -> String {
        return """
        {
            "name": "cool-style",
            "version": 8,
            "transition": {
              "duration": 1000,
              "delay": 0
            },
            "sources": {
                  \(countriesSource())
                  \(discoGridSources())
            },
            "layers": [
                {
                    "id": "background-layer",
                    "type": "background",
                    "paint": {
                        "background-color": "white"
                    }
                },
                \(customLayers())
            ]
        }
        """
    }

    func discoGridSources() -> String {
        // A random even grid of squares on the map, which are used
        // as the tiles on the surface of the disco ball
        let grid: [[[Int]]] = {
            var res: [[[Int]]]  = []
            for lon in stride(from: -180, to: 180, by: 10) {
                for lat in stride(from: -90, to: 90, by: 10) {
                    let rect: [[Int]] = [
                        [lon, lat], [lon + 10, lat],
                        [lon + 10, lat + 10], [lon, lat + 10]
                    ]
                    res.append(rect)
                }
            }
            return res.shuffled()
        }()

        let groupSize = (grid.count / Constants.FrequencySplit)
        var res = ""
        for group in 0 ..< Constants.FrequencySplit {
            let offset = groupSize * group
            var featureString = ""
            for index in 0...groupSize {
                let geo = grid[offset + index]
                if let data = try? JSONEncoder().encode(geo) {
                    let feature = """
                    {
                        "type": "Feature",
                        "geometry": {
                            "type": "Polygon",
                            "coordinates": [\(String(decoding: data, as: UTF8.self))]
                        }
                    }\(index == (groupSize) ? "" : ",")
                    """
                    featureString += feature
                }
            }

            let source = """
            "extrusions-\(group)": {
                "type": "geojson",
                "data": {
                    "type": "FeatureCollection",
                    "features": [\(featureString)]
                }
            }\(group == (Constants.FrequencySplit-1) ? "" : ",")
            """
            res += source
        }
        return res
    }

    func countriesSource() -> String {
        // Source of GeoJSON: https://geojson-maps.ash.ms/
        var res = ""
        if let fileURL = Bundle.main.url(forResource: "custom.geo", withExtension: "json") {
            if let fileContents = try? String(contentsOf: fileURL) {
                res += "\"countries\": { \"type\": \"geojson\", \"data\": \(fileContents)},"
            }
        }
        return res
    }

    func customLayers() -> String {
        var res = ""
        // Countries
        for index in 0..<Constants.FrequencySplit {
            let groupSize = (Constants.CountryCodes.count/Constants.FrequencySplit)
            let postalCodes = Array(Constants.CountryCodes[(groupSize*index)..<(groupSize*(index+1))])
            let layer = """
            {
                "id": "countries-\(index)",
                "type": "fill-extrusion",
                "source": "countries",
                "filter": ["in",
                    ["get", "postal"],
                    ["literal", \(postalCodes)]
                ],
                "paint": {
                    "fill-extrusion-color": "\(UIColor.random.toRgbaString())",
                    "fill-extrusion-height": 2000.0,
                    "fill-extrusion-opacity": 1.0
                }
            },
            """
            res += layer
        }
        // Disco grid tiles
        for index in 0..<Constants.FrequencySplit {
            let layer = """
            {
                \"id\": \"columns-\(index)\",
                \"type\": \"fill\",
                \"source\": \"extrusions-\(index)\",
                \"paint\": {
                    \"fill-color\": \"\(UIColor.random.toRgbaString())\"
                }
            },
            """
            res += layer
        }
        // Light rays
        let rayLayer = """
        {
            "id": "rays",
            "type": "fill-extrusion",
            "source": "extrusions-3",
            "paint": {
                "fill-extrusion-color": "white",
                "fill-extrusion-height": 100000000.0,
                "fill-extrusion-base": 2000000.0,
                "fill-extrusion-opacity": 0.1
            }
        }
        """
        res += rayLayer
        return res
    }

}

private class AudioAnalyzer {

    var amps = [Double](repeating: 0.0, count: Int(Constants.FrequencySplit))
    var globalAmp = 0.0

    private let engine = AudioEngine()
    private var ampTap: AmplitudeTap?
    private var fftTap: FFTTap?
    private let mic: AudioEngine.InputNode?
    private let outputMixer: Mixer
    private let ampMixer: Mixer
    private let fftMixer: Mixer

    init() {
        mic = engine.input
        mic?.volume = 30.0

        ampMixer = Mixer(mic!)
        fftMixer = Mixer(ampMixer)
        outputMixer = Mixer(fftMixer)
        engine.output = Fader(fftMixer, gain: 0)

        do {
            try engine.start()
        } catch {}

        fftTap = FFTTap(fftMixer, handler: { [weak self] fftData in
            guard let self = self else { return }
            // From: https://github.com/vivjay30/MobileWireless/
            for index in stride(from: 0, to: Constants.FftSize, by: 2) {
                let real = fftData[Int(index)]
                let imag = fftData[Int(index) + 1]
                let normBinMag = 2.0 * sqrt(real * real + imag * imag) / Float(Constants.FftSize)
                let amplitude = ((20.0 * log10(normBinMag)))
                self.amps[(Int(index) / Constants.SampleCount)] += Double(amplitude)
            }
            for index in 0..<Constants.FrequencySplit {
                self.amps[index] = self.amps[index] / Double(Constants.SampleCount)
            }
            let max = self.amps.max()!
            let min = self.amps.min()!
            for index in 0..<Constants.FrequencySplit {
                self.amps[index] = (self.amps[index] - min) / ((max - min) + 0.001)
                if self.amps[index] < 0.0 {
                    self.amps[index] = 0.0
                }
            }
        })

        fftTap?.start()

        ampTap = AmplitudeTap(ampMixer, handler: { [weak self] res in
            self?.globalAmp = max(min(pow(Double(res), 2.0), 5.0), 0.0)
        })

        ampTap?.start()
    }

}

extension UIColor {
    static var random: UIColor {
        // Only the hue is randomized to keep the colors vivid
        return .init(hue: .random(in: 0...1), saturation: 1, brightness: 1, alpha: 1)
    }

    func toRgbaString() -> String {
        let ciColor = CIColor(color: self)
        return "rgba(\(ciColor.red * 255.0), \(ciColor.green * 255.0), \(ciColor.blue * 255.0), \(ciColor.alpha))"
    }
}
