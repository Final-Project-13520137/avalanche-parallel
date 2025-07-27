// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

// This script generates visualization graphs for benchmark results
// Run with: go run scripts/visualize_benchmark.go benchmark-results/benchmark-*.md

package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/wcharczuk/go-chart/v2"
	"github.com/wcharczuk/go-chart/v2/drawing"
)

// Structure to hold benchmark data
type BenchmarkData struct {
	Date            string
	BestSpeedup     float64
	BestThreads     int
	TxProfile       string
	TxCount         int
	BatchSize       int
	ThreadResults   []ThreadResult
	TestCase        string
	ProcessingTimes map[string]float64
}

// Structure to hold thread benchmark results
type ThreadResult struct {
	Threads        int
	ParallelTime   float64
	SequentialTime float64
	Speedup        float64
}

// Test case specific data
type TestCaseData struct {
	Name           string
	TradTime       float64
	ParaTime       float64
	Speedup        float64
	TransactionSize string
}

func main() {
	// Parse command line flags
	outputDir := flag.String("output", "benchmark-results", "Directory to save visualization graphs")
	flag.Parse()

	// Get benchmark files from command line arguments
	benchmarkFiles := flag.Args()
	if len(benchmarkFiles) == 0 {
		// If no files provided, try to find them in the benchmark-results directory
		var err error
		benchmarkFiles, err = filepath.Glob("benchmark-results/benchmark-*.md")
		if err != nil || len(benchmarkFiles) == 0 {
			log.Fatalf("No benchmark files provided and none found in benchmark-results directory")
		}
	}

	// Create output directory if it doesn't exist
	if _, err := os.Stat(*outputDir); os.IsNotExist(err) {
		os.Mkdir(*outputDir, 0755)
		fmt.Printf("Created output directory: %s\n", *outputDir)
	}

	// Parse benchmark files
	fmt.Println("Parsing benchmark files...")
	benchmarks := make([]BenchmarkData, 0, len(benchmarkFiles))
	testCases := make([]TestCaseData, 0)

	for _, file := range benchmarkFiles {
		fmt.Printf("Processing: %s\n", file)
		benchmark, err := parseBenchmarkFile(file)
		if err != nil {
			fmt.Printf("Error parsing %s: %v\n", file, err)
			continue
		}
		benchmarks = append(benchmarks, benchmark)

		// Extract test case information from filename if available
		baseName := filepath.Base(file)
		if strings.Contains(baseName, "small") {
			testCases = append(testCases, TestCaseData{
				Name:            "Small Transactions",
				TradTime:        benchmark.ThreadResults[0].SequentialTime,
				ParaTime:        benchmark.ThreadResults[len(benchmark.ThreadResults)-1].ParallelTime,
				Speedup:         benchmark.BestSpeedup,
				TransactionSize: "small",
			})
		} else if strings.Contains(baseName, "medium") {
			testCases = append(testCases, TestCaseData{
				Name:            "Medium Transactions",
				TradTime:        benchmark.ThreadResults[0].SequentialTime,
				ParaTime:        benchmark.ThreadResults[len(benchmark.ThreadResults)-1].ParallelTime,
				Speedup:         benchmark.BestSpeedup,
				TransactionSize: "medium",
			})
		} else if strings.Contains(baseName, "large") {
			testCases = append(testCases, TestCaseData{
				Name:            "Large Transactions",
				TradTime:        benchmark.ThreadResults[0].SequentialTime,
				ParaTime:        benchmark.ThreadResults[len(benchmark.ThreadResults)-1].ParallelTime,
				Speedup:         benchmark.BestSpeedup,
				TransactionSize: "large",
			})
		} else if strings.Contains(baseName, "mixed") {
			testCases = append(testCases, TestCaseData{
				Name:            "Mixed Transactions",
				TradTime:        benchmark.ThreadResults[0].SequentialTime,
				ParaTime:        benchmark.ThreadResults[len(benchmark.ThreadResults)-1].ParallelTime,
				Speedup:         benchmark.BestSpeedup,
				TransactionSize: "mixed",
			})
		}
	}

	// If we have at least one benchmark, generate visualizations
	if len(benchmarks) > 0 {
		fmt.Println("Generating visualizations...")
		
		// For each benchmark, create a visualization
		for _, benchmark := range benchmarks {
			// Create processing time comparison chart
			createProcessingTimeChart(benchmark, *outputDir)
			
			// Create speedup chart
			createSpeedupChart(benchmark, *outputDir)
			
			// Create transactions per second chart
			createTpsChart(benchmark, *outputDir)
		}
		
		// If we have test case data, create test case comparison charts
		if len(testCases) > 0 {
			createTestCaseComparisonChart(testCases, *outputDir)
		}
		
		fmt.Println("Visualization complete!")
	} else {
		fmt.Println("No valid benchmark data found.")
	}
}

// Parse benchmark file and extract data
func parseBenchmarkFile(filePath string) (BenchmarkData, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return BenchmarkData{}, err
	}
	defer file.Close()

	data := BenchmarkData{
		ThreadResults:   make([]ThreadResult, 0),
		ProcessingTimes: make(map[string]float64),
	}

	// Extract test case from filename
	baseName := filepath.Base(filePath)
	if strings.Contains(baseName, "small") {
		data.TestCase = "Small Transactions"
	} else if strings.Contains(baseName, "medium") {
		data.TestCase = "Medium Transactions"
	} else if strings.Contains(baseName, "large") {
		data.TestCase = "Large Transactions"
	} else if strings.Contains(baseName, "mixed") {
		data.TestCase = "Mixed Transactions"
	} else {
		data.TestCase = "Default Test Case"
	}

	scanner := bufio.NewScanner(file)
	inTable := false
	
	// Regular expressions for parsing
	dateRegex := regexp.MustCompile(`\*\*Date:\*\* (.+)`)
	speedupRegex := regexp.MustCompile(`\*\*Best Speedup:\*\* ([0-9.]+)x with ([0-9]+) threads`)
	txProfileRegex := regexp.MustCompile(`\*\*Transaction Profile:\*\* (.+)`)
	txCountRegex := regexp.MustCompile(`\*\*Transaction Count:\*\* ([0-9]+)`)
	batchSizeRegex := regexp.MustCompile(`\*\*Batch Size:\*\* ([0-9]+)`)
	
	for scanner.Scan() {
		line := scanner.Text()
		
		// Parse summary section
		if match := dateRegex.FindStringSubmatch(line); match != nil {
			data.Date = match[1]
		} else if match := speedupRegex.FindStringSubmatch(line); match != nil {
			data.BestSpeedup, _ = strconv.ParseFloat(match[1], 64)
			data.BestThreads, _ = strconv.Atoi(match[2])
		} else if match := txProfileRegex.FindStringSubmatch(line); match != nil {
			data.TxProfile = match[1]
		} else if match := txCountRegex.FindStringSubmatch(line); match != nil {
			data.TxCount, _ = strconv.Atoi(match[1])
		} else if match := batchSizeRegex.FindStringSubmatch(line); match != nil {
			data.BatchSize, _ = strconv.Atoi(match[1])
		}
		
		// Check if we're in the results table
		if strings.Contains(line, "|---------|") {
			inTable = true
			continue
		}
		
		// Parse table rows
		if inTable && strings.HasPrefix(line, "|") {
			parts := strings.Split(line, "|")
			if len(parts) >= 5 {
				threads, _ := strconv.Atoi(strings.TrimSpace(parts[1]))
				parallelTime, _ := strconv.ParseFloat(strings.TrimSuffix(strings.TrimSpace(parts[2]), "s"), 64)
				sequentialTime, _ := strconv.ParseFloat(strings.TrimSuffix(strings.TrimSpace(parts[3]), "s"), 64)
				speedup, _ := strconv.ParseFloat(strings.TrimSuffix(strings.TrimSpace(parts[4]), "x"), 64)
				
				data.ThreadResults = append(data.ThreadResults, ThreadResult{
					Threads:        threads,
					ParallelTime:   parallelTime,
					SequentialTime: sequentialTime,
					Speedup:        speedup,
				})
			}
		}
	}

	if err := scanner.Err(); err != nil {
		return data, err
	}

	return data, nil
}

// Create a chart comparing processing times
func createProcessingTimeChart(data BenchmarkData, outputDir string) {
	// Prepare data for the chart
	threads := make([]float64, len(data.ThreadResults))
	traditionalTimes := make([]float64, len(data.ThreadResults))
	parallelTimes := make([]float64, len(data.ThreadResults))
	
	for i, result := range data.ThreadResults {
		threads[i] = float64(result.Threads)
		traditionalTimes[i] = result.SequentialTime
		parallelTimes[i] = result.ParallelTime
	}
	
	// Create a new chart
	graph := chart.Chart{
		Title: fmt.Sprintf("Processing Time Comparison - %s", data.TestCase),
		Background: chart.Style{
			Padding: chart.Box{
				Top:    20,
				Left:   20,
				Right:  20,
				Bottom: 20,
			},
		},
		XAxis: chart.XAxis{
			Name: "Threads",
		},
		YAxis: chart.YAxis{
			Name: "Processing Time (seconds)",
		},
		Series: []chart.Series{
			chart.ContinuousSeries{
				Name:    "Traditional (Single Thread)",
				XValues: threads,
				YValues: traditionalTimes,
				Style: chart.Style{
					StrokeColor: drawing.ColorRed,
					StrokeWidth: 2,
				},
			},
			chart.ContinuousSeries{
				Name:    "Parallel",
				XValues: threads,
				YValues: parallelTimes,
				Style: chart.Style{
					StrokeColor: drawing.ColorBlue,
					StrokeWidth: 2,
				},
			},
		},
	}
	
	// Add a legend
	graph.Elements = []chart.Renderable{
		chart.LegendThin(&graph),
	}
	
	// Save the chart to a PNG file
	timestamp := time.Now().Format("20060102_150405")
	fileName := fmt.Sprintf("%s/processing_time_%s_%s.png", outputDir, data.TestCase, timestamp)
	f, err := os.Create(fileName)
	if err != nil {
		fmt.Printf("Error creating file: %v\n", err)
		return
	}
	defer f.Close()
	
	err = graph.Render(chart.PNG, f)
	if err != nil {
		fmt.Printf("Error rendering chart: %v\n", err)
		return
	}
	
	fmt.Printf("Created chart: %s\n", fileName)
}

// Create a chart showing speedup factor
func createSpeedupChart(data BenchmarkData, outputDir string) {
	// Prepare data for the chart
	threads := make([]float64, len(data.ThreadResults))
	speedups := make([]float64, len(data.ThreadResults))
	
	for i, result := range data.ThreadResults {
		threads[i] = float64(result.Threads)
		speedups[i] = result.Speedup
	}
	
	// Create a new chart
	graph := chart.Chart{
		Title: fmt.Sprintf("Speedup Factor - %s", data.TestCase),
		Background: chart.Style{
			Padding: chart.Box{
				Top:    20,
				Left:   20,
				Right:  20,
				Bottom: 20,
			},
		},
		XAxis: chart.XAxis{
			Name: "Threads",
		},
		YAxis: chart.YAxis{
			Name: "Speedup (x)",
		},
		Series: []chart.Series{
			chart.ContinuousSeries{
				Name:    "Speedup Factor",
				XValues: threads,
				YValues: speedups,
				Style: chart.Style{
					StrokeColor: drawing.ColorGreen,
					StrokeWidth: 2,
				},
			},
			// Add an ideal linear speedup line for comparison
			chart.ContinuousSeries{
				Name:    "Ideal Linear Speedup",
				XValues: threads,
				YValues: threads, // Linear speedup would match thread count
				Style: chart.Style{
					StrokeColor:     drawing.ColorFromHex("AAAAAA"),
					StrokeWidth:     1,
					StrokeDashArray: []float64{5, 5},
				},
			},
		},
	}
	
	// Add a legend
	graph.Elements = []chart.Renderable{
		chart.LegendThin(&graph),
	}
	
	// Save the chart to a PNG file
	timestamp := time.Now().Format("20060102_150405")
	fileName := fmt.Sprintf("%s/speedup_factor_%s_%s.png", outputDir, data.TestCase, timestamp)
	f, err := os.Create(fileName)
	if err != nil {
		fmt.Printf("Error creating file: %v\n", err)
		return
	}
	defer f.Close()
	
	err = graph.Render(chart.PNG, f)
	if err != nil {
		fmt.Printf("Error rendering chart: %v\n", err)
		return
	}
	
	fmt.Printf("Created chart: %s\n", fileName)
}

// Create a chart showing transactions per second
func createTpsChart(data BenchmarkData, outputDir string) {
	// Prepare data for the chart
	threads := make([]float64, len(data.ThreadResults))
	traditionalTps := make([]float64, len(data.ThreadResults))
	parallelTps := make([]float64, len(data.ThreadResults))
	
	for i, result := range data.ThreadResults {
		threads[i] = float64(result.Threads)
		// Calculate transactions per second (assuming data.TxCount is the total number of transactions)
		traditionalTps[i] = float64(data.TxCount) / result.SequentialTime
		parallelTps[i] = float64(data.TxCount) / result.ParallelTime
	}
	
	// Create a new chart
	graph := chart.Chart{
		Title: fmt.Sprintf("Transactions Per Second - %s", data.TestCase),
		Background: chart.Style{
			Padding: chart.Box{
				Top:    20,
				Left:   20,
				Right:  20,
				Bottom: 20,
			},
		},
		XAxis: chart.XAxis{
			Name: "Threads",
		},
		YAxis: chart.YAxis{
			Name: "Transactions/second",
		},
		Series: []chart.Series{
			chart.ContinuousSeries{
				Name:    "Traditional (Single Thread)",
				XValues: threads,
				YValues: traditionalTps,
				Style: chart.Style{
					StrokeColor: drawing.ColorRed,
					StrokeWidth: 2,
				},
			},
			chart.ContinuousSeries{
				Name:    "Parallel",
				XValues: threads,
				YValues: parallelTps,
				Style: chart.Style{
					StrokeColor: drawing.ColorBlue,
					StrokeWidth: 2,
				},
			},
		},
	}
	
	// Add a legend
	graph.Elements = []chart.Renderable{
		chart.LegendThin(&graph),
	}
	
	// Save the chart to a PNG file
	timestamp := time.Now().Format("20060102_150405")
	fileName := fmt.Sprintf("%s/transactions_per_second_%s_%s.png", outputDir, data.TestCase, timestamp)
	f, err := os.Create(fileName)
	if err != nil {
		fmt.Printf("Error creating file: %v\n", err)
		return
	}
	defer f.Close()
	
	err = graph.Render(chart.PNG, f)
	if err != nil {
		fmt.Printf("Error rendering chart: %v\n", err)
		return
	}
	
	fmt.Printf("Created chart: %s\n", fileName)
}

// Create a chart comparing test cases
func createTestCaseComparisonChart(testCases []TestCaseData, outputDir string) {
	if len(testCases) < 2 {
		fmt.Println("Not enough test cases for comparison chart")
		return
	}
	
	// Prepare data for the bar chart
	names := make([]string, len(testCases))
	traditionalTimes := make([]float64, len(testCases))
	parallelTimes := make([]float64, len(testCases))
	speedups := make([]float64, len(testCases))
	
	for i, tc := range testCases {
		names[i] = tc.Name
		traditionalTimes[i] = tc.TradTime
		parallelTimes[i] = tc.ParaTime
		speedups[i] = tc.Speedup
	}
	
	// Processing time comparison
	timeChart := chart.BarChart{
		Title: "Processing Time by Test Case",
		Background: chart.Style{
			Padding: chart.Box{
				Top:    20,
				Left:   20,
				Right:  20,
				Bottom: 70,
			},
		},
		Width:  800,
		Height: 500,
		XAxis: chart.Style{
			TextRotationDegrees: 45.0,
		},
		YAxis: chart.YAxis{
			Name: "Processing Time (seconds)",
		},
		Bars: []chart.Value{},
	}
	
	// Add traditional time bars
	for i, name := range names {
		timeChart.Bars = append(timeChart.Bars, chart.Value{
			Value: traditionalTimes[i],
			Label: name + " (Traditional)",
			Style: chart.Style{
				FillColor:   drawing.ColorRed,
				StrokeColor: drawing.ColorRed,
				StrokeWidth: 0,
			},
		})
	}
	
	// Add parallel time bars
	for i, name := range names {
		timeChart.Bars = append(timeChart.Bars, chart.Value{
			Value: parallelTimes[i],
			Label: name + " (Parallel)",
			Style: chart.Style{
				FillColor:   drawing.ColorBlue,
				StrokeColor: drawing.ColorBlue,
				StrokeWidth: 0,
			},
		})
	}
	
	// Save the processing time chart
	timestamp := time.Now().Format("20060102_150405")
	timeFileName := fmt.Sprintf("%s/test_case_time_comparison_%s.png", outputDir, timestamp)
	tf, err := os.Create(timeFileName)
	if err != nil {
		fmt.Printf("Error creating file: %v\n", err)
		return
	}
	defer tf.Close()
	
	err = timeChart.Render(chart.PNG, tf)
	if err != nil {
		fmt.Printf("Error rendering chart: %v\n", err)
		return
	}
	
	fmt.Printf("Created chart: %s\n", timeFileName)
	
	// Speedup comparison
	speedupChart := chart.BarChart{
		Title: "Speedup Factor by Test Case",
		Background: chart.Style{
			Padding: chart.Box{
				Top:    20,
				Left:   20,
				Right:  20,
				Bottom: 70,
			},
		},
		Width:  800,
		Height: 500,
		XAxis: chart.Style{
			TextRotationDegrees: 45.0,
		},
		YAxis: chart.YAxis{
			Name: "Speedup Factor (x)",
		},
		Bars: []chart.Value{},
	}
	
	// Add speedup bars
	for i, name := range names {
		speedupChart.Bars = append(speedupChart.Bars, chart.Value{
			Value: speedups[i],
			Label: name,
			Style: chart.Style{
				FillColor:   drawing.ColorGreen,
				StrokeColor: drawing.ColorGreen,
				StrokeWidth: 0,
			},
		})
	}
	
	// Save the speedup chart
	speedupFileName := fmt.Sprintf("%s/test_case_speedup_comparison_%s.png", outputDir, timestamp)
	sf, err := os.Create(speedupFileName)
	if err != nil {
		fmt.Printf("Error creating file: %v\n", err)
		return
	}
	defer sf.Close()
	
	err = speedupChart.Render(chart.PNG, sf)
	if err != nil {
		fmt.Printf("Error rendering chart: %v\n", err)
		return
	}
	
	fmt.Printf("Created chart: %s\n", speedupFileName)
} 