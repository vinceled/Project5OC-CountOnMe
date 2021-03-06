//
//  CountOnMe.swift
//  CountOnMe
//
//  Created by Mark LEDOUX on 20/09/2019.
//  Copyright © 2019 Vincent Saluzzo. All rights reserved.
//

import Foundation

final class Calculator {

	// MARK: - Public Properties
	weak var delegate: CalculatorDelegate?

	/*
	Acccess level for printedString is marked with a private(set) modifier,
	Indicate that the property’s getter still has the default access level of internal,
	But the property is settable only from within code that’s part of Calculator.
	This enables Calculator to modify printedString internally,
	Present the property as a read-only property when it’s used outside.
	*/
	private(set) var printedString: String = "0" {
		didSet {
			delegate?.didUpdatePrintedString()
		}
	}

	// MARK: - Public Methods
	/// Set printedString to "" then add a number
	func addNumber(_ numberText: String) {
		if isResultDisplayed {
			printedString = ""
		}
		isResultDisplayed = false

		isEmpty()
		removeFirstZero()

		printedString.append(numberText)
	}

	/// contains operators or is last element operator?
	func add(mathOperator: MathOperator) {
		if isResultDisplayed {
			printedString = ""
		}
		isResultDisplayed = false
		removeLastOperatorIfNecessary()
		printedString.append(" \(mathOperator.rawValue) ")
		removeFirstOperatorIfNecessary()
	}

	/// resetting whatever value held by printedString to 0 then nothing so a new operation can be started
	func reset() {
		printedString = "0"
		isResultDisplayed = false
	}

	/// processing all the elements contained in printedString to return a result
	// swiftlint:disable:next  function_body_length
	func reduce() {
		isResultDisplayed = true

		do {
			try checkEquationValidity()
		} catch CalculatorError.missingElement {
			return
		} catch {}

		/// Create local copy of operations
		var operationsToReduce = elements
		/// when looping in the array, the minimum value of the first index
		var currentOperationUnitIndex = 0

		/// Iterate over operations while an operand still here
		while operationsToReduce.count > 1 {
			/// Assigning operators a value of currentUnitIndex + 1
			let mathOperator = operationsToReduce[currentOperationUnitIndex + 1]
			/// Check if operationsToReduce still contains priority operators
			let operationsContainsPriorityOperator =
				operationContainsPriorityOperator(operationsToReduce: operationsToReduce)

			let isPriorityOperators = isPriorityOperator(mathOperator: mathOperator)
			/// Check for priority operator and first loop
			guard isPriorityOperators || !operationsContainsPriorityOperator else {
				currentOperationUnitIndex += 2
				continue
			}
			/// Setting UnitIndex back to zero when not on first loop
			if !operationsContainsPriorityOperator {
				currentOperationUnitIndex = 0
			}
			///Giving left and right UnitIndex value of 0 and 2
			let left = operationsToReduce[currentOperationUnitIndex]
			let right = operationsToReduce[currentOperationUnitIndex + 2]

			guard let leftValue = Double(left) else {
				printedString = CalculatorError.leftOperatorNotValid.localizedDescription
				return
			}

			guard let rightValue = Double(right) else {
				printedString = CalculatorError.rightOperatorNotValid.localizedDescription
				return
			}

			let result: Double
			switch mathOperator {
			case MathOperator.addition.rawValue: result = leftValue + rightValue
			case MathOperator.substraction.rawValue: result = leftValue - rightValue
			case MathOperator.multiplication.rawValue: result = leftValue * rightValue
			case MathOperator.division.rawValue:
				do { try verifyCanDivide(leftValue, by: rightValue) } catch {
					printedString = CalculatorError.zeroDivisor.localizedDescription
					return
				}
				result = leftValue / rightValue
			default:
				/// an assertion to stop the program's execution is something outside of the cases is encountered
				/// doesn't impact shipping in any way
				assertionFailure(CalculatorError.missingElement.localizedDescription)
			return
			}
			cleanEquation(operationsToReduce: &operationsToReduce,
						  result: result, currentOperationUnitIndex: currentOperationUnitIndex)
			// setting currentOperationUnitIndex back to 0 at the end of the loop
			currentOperationUnitIndex = 0
		}
	}

	// MARK: - Private Properties
	/// separating all the elements of printedString so they can be used individually throughout the code
	private var elements: [String] {
		return printedString.split(separator: " ").map { "\($0)" }
	}

	/// making sure that the elements composing printedString are always above or equal to 3
	private var expressionHaveEnoughElement: Bool {
		return elements.count >= 3
	}

	/// check if the previous expression was processed successfully
	private var isResultDisplayed = false

	/// property to say how many numbers after the decimal are allowed
	private var numberFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.groupingSeparator = ""
		formatter.minimumFractionDigits = 0
		formatter.maximumFractionDigits = 5

		formatter.numberStyle = .decimal
		formatter.decimalSeparator = "."
		return formatter
	}()

	/// Loop on all the cases for the operators in MathOperator to see if last in element
	private var isLastElementOperator: Bool {
		for mathOperator in MathOperator.allCases where mathOperator.rawValue == elements.last {
				return true
		}
		return false
	}

	private var isFirstElementOperator: Bool {
		for mathOperator in MathOperator.allCases where mathOperator.rawValue == elements.first {
			return true
		}
		return false
	}

	/// check first element is zero
	private var isFirstElementZeroNumber: Bool {
		for mathOperator in MathOperator.allCases where elements.contains(mathOperator.rawValue) && elements.last == "0" {
			return true
		}
		return false
	}

	// MARK: Methods - Private
	/// operationsToReduce contains priority operator?
	private func operationContainsPriorityOperator(operationsToReduce: [String]) -> Bool {
		operationsToReduce.contains { isPriorityOperator(mathOperator: $0) }
	}

	///handling possible errors in case the expression processed doesn't contain all the necessary elements
	private func checkEquationValidity() throws {

		guard expressionHaveEnoughElement else {
			printedString = CalculatorError.missingElement.localizedDescription
			throw CalculatorError.missingElement
		}

		guard !isLastElementOperator else {
			printedString = CalculatorError.missingElement.localizedDescription
			throw CalculatorError.missingElement
		}
	}

	/// transforming the double from the result into a string so it can be displayed by the view
	private func formatNumberToString(number: Double) -> String? {
		return numberFormatter.string(from: number as NSNumber)
	}

	/// function which makes it possible to handle priority of operations
	private func cleanEquation(operationsToReduce: inout [String], result: Double, currentOperationUnitIndex: Int) {

		guard let resultAsString = formatNumberToString(number: result) else { return }

		operationsToReduce.remove(at: currentOperationUnitIndex)
		operationsToReduce.remove(at: currentOperationUnitIndex)
		operationsToReduce.remove(at: currentOperationUnitIndex)
		operationsToReduce.insert(resultAsString, at: currentOperationUnitIndex)

		guard let resultToPrint = operationsToReduce.first else {
			return
		}
		printedString = resultToPrint
	}

	/// Verifying that the left value can be divide by the right value
	private func verifyCanDivide(_ left: Double, by right: Double) throws {
		guard right != 0 else {
			throw CalculatorError.zeroDivisor
		}
	}

	/// check in the operators to see whether the operators used are piority operators or not and returning a boolean
	private func isPriorityOperator(mathOperator: String) -> Bool {
		switch mathOperator {
		case MathOperator.multiplication.rawValue, MathOperator.division.rawValue: return true
		default: return false
		}
	}

	/// check to see if an operand is contained within printedString and if true then remove the copy of the operand
	private func removeLastOperatorIfNecessary() {
		if isLastElementOperator {
			printedString.removeLast(3)
		}
	}

	private func removeFirstOperatorIfNecessary() {
		if isFirstElementOperator {
			printedString = "0"
		}
	}

	///check if printedString is empty
	private func isEmpty() {
		if !printedString.isEmpty || printedString.isEmpty {
			if printedString.first == "0" {
				printedString = ""
			}
		}
	}

	/// removing zero if it is the first number
	private func removeFirstZero() {
		if isFirstElementZeroNumber {
			printedString.removeLast()
		}
	}
}
