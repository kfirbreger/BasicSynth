//
//  ParameterRamp.swift
//  BasicSynth
//
//  Created by Kfir Breger on 26/09/2026.
//

/*
 Abstract:
 The parameter ramp produces a linear ramp to smooth out parameter changes and avoid audio artifacts.
 */

nonisolated struct ParameterRamp {
   
    public mutating func setup(_ value: Float) {
        currentValue = value
        targetValue = value
    }
    
    public mutating func setRampLength(_ length: Float) {
        rampLength = length
    }
    
    public mutating func setTargetValue(_ value: Float) {
        targetValue = value
        // Update the ramp increment
        rampIncrement = (targetValue - currentValue) / rampLength
    }
    
    public mutating func nextValue() -> Float {
        // If target value has been reached, return it
        if (currentValue == targetValue) {
            return currentValue
        }
        
        // Otherwise, ramp up
        currentValue += rampIncrement
        
        // If the distance between current and target is less than the increment, stop ramping
        if (abs(currentValue - targetValue) < abs(rampIncrement)) {
            currentValue = targetValue
        }
        
        return currentValue
    }
    
    init(value: Float) {
        self.currentValue = value
        self.targetValue = value
    }
    
    private var currentValue: Float = 0
    private var targetValue: Float = 0
    private var rampLength: Float = 0
    private var rampIncrement: Float = 0
}
