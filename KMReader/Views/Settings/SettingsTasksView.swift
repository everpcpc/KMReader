//
//  SettingsTasksView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsTasksView: View {
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @AppStorage("taskQueueStatus") private var taskQueueStatus: TaskQueueSSEDto = TaskQueueSSEDto()

  @State private var isLoading = false
  @State private var isCancelling = false
  @State private var showCancelAllConfirmation = false

  // Tasks metrics
  @State private var tasks: Metric?
  @State private var tasksCountByType: [String: Double] = [:]
  @State private var tasksTotalTimeByType: [String: Double] = [:]
  @State private var metricErrors: [TaskErrorKey: String] = [:]

  var body: some View {
    Form {
      if !isAdmin {
        AdminRequiredView()
      } else if isLoading {
        Section {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        }
      } else {
        #if os(tvOS)
          HStack {
            Spacer()
            Button {
              showCancelAllConfirmation = true
            } label: {
              if isCancelling {
                ProgressView()
              } else {
                Text("Cancel All")
              }
            }
            .buttonStyle(.plain)
            .disabled(isCancelling)
          }
        #else
          if isAdmin {
            Section {
              Button(role: .destructive) {
                showCancelAllConfirmation = true
              } label: {
                HStack {
                  Spacer()
                  if isCancelling {
                    ProgressView()
                  } else {
                    Label("Cancel All Tasks", systemImage: "xmark.circle")
                  }
                  Spacer()
                }
              }
              .disabled(isCancelling)
            }
          }
        #endif

        // Task Queue Status Section (from SSE)
        if taskQueueStatus.count > 0 {
          Section {
            VStack(spacing: 12) {
              // Total Tasks with highlight
              HStack {
                Label("Total Tasks", systemImage: "list.bullet.clipboard")
                  .font(.headline)
                Spacer()
                Text("\(taskQueueStatus.count)")
                  .font(.title2)
                  .fontWeight(.bold)
                  .foregroundColor(taskQueueStatus.count > 0 ? themeColor.color : .secondary)
                  .contentTransition(.numericText())
              }
              .padding(.vertical, 4)
              #if os(tvOS)
                .focusable()
              #endif

              // Task types with animation
              if !taskQueueStatus.countByType.isEmpty {
                Divider()
                ForEach(Array(taskQueueStatus.countByType.keys.sorted()), id: \.self) { taskType in
                  if let count = taskQueueStatus.countByType[taskType] {
                    HStack {
                      Label(taskType, systemImage: "gearshape")
                        .font(.subheadline)
                      Spacer()
                      Text("\(count)")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(count > 0 ? themeColor.color : .secondary)
                        .contentTransition(.numericText())
                    }
                    .padding(.vertical, 2)
                    #if os(tvOS)
                      .focusable()
                    #endif
                  }
                }
              }
            }
            .padding(.vertical, 8)
          } header: {
            HStack {
              Text("Task Queue Status")
                .font(.headline)
              Spacer()
              if taskQueueStatus.count > 0 {
                Circle()
                  .fill(themeColor.color)
                  .frame(width: 8, height: 8)
                  .opacity(1.0)
              }
            }
          }
          .transition(.opacity.combined(with: .move(edge: .top)))
          .animation(.spring(response: 0.3, dampingFraction: 0.7), value: taskQueueStatus.count)
          .animation(
            .spring(response: 0.3, dampingFraction: 0.7), value: taskQueueStatus.countByType)
        }

        // Tasks Section
        if !tasksCountByType.isEmpty || metricErrors[.tasksExecuted] != nil {
          Section(header: Text("Tasks Executed")) {
            ForEach(Array(tasksCountByType.keys.sorted()), id: \.self) { taskType in
              if let count = tasksCountByType[taskType] {
                HStack {
                  Label(taskType, systemImage: "gearshape")
                  Spacer()
                  Text(formatNumber(count))
                    .foregroundColor(.secondary)
                }
                #if os(tvOS)
                  .focusable()
                #endif
              }
            }
            if let error = metricErrors[.tasksExecuted] {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                Text(error)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              #if os(tvOS)
                .focusable()
              #endif
            }
          }
        }

        if !tasksTotalTimeByType.isEmpty || metricErrors[.tasksTotalTime] != nil {
          Section(header: Text("Tasks Total Time")) {
            ForEach(Array(tasksTotalTimeByType.keys.sorted()), id: \.self) { taskType in
              if let time = tasksTotalTimeByType[taskType] {
                HStack {
                  Label(taskType, systemImage: "clock")
                  Spacer()
                  Text(String(format: "%.2f s", time))
                    .foregroundColor(.secondary)
                }
                #if os(tvOS)
                  .focusable()
                #endif
              }
            }
            if let error = metricErrors[.tasksTotalTime] {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                Text(error)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              #if os(tvOS)
                .focusable()
              #endif
            }
          }
        }
      }
    }
    .formStyle(.grouped)
    .inlineNavigationBarTitle("Tasks")
    .alert("Cancel All Tasks", isPresented: $showCancelAllConfirmation) {
      Button("Cancel", role: .cancel) {}
      Button("Confirm", role: .destructive) {
        cancelAllTasks()
      }
    } message: {
      Text("Are you sure you want to cancel all tasks? This action cannot be undone.")
    }
    .task {
      if isAdmin {
        await loadMetrics()
      }
    }
    .refreshable {
      if isAdmin {
        await loadMetrics()
      }
    }
  }

  private func loadMetrics() async {
    isLoading = true
    metricErrors.removeAll()

    // Load tasks metrics
    do {
      let metric = try await ManagementService.shared.getMetric(MetricName.tasksExecution.rawValue)
      tasks = metric

      let (countByType, totalTimeByType, errors) = await processTasksMetrics(metric)
      tasksCountByType = countByType
      tasksTotalTimeByType = totalTimeByType
      if let tasksExecutedError = errors[.tasksExecuted] {
        metricErrors[.tasksExecuted] = tasksExecutedError
      }
      if let tasksTotalTimeError = errors[.tasksTotalTime] {
        metricErrors[.tasksTotalTime] = tasksTotalTimeError
      }
    } catch {
      tasks = nil
    }

    isLoading = false
  }

  private func cancelAllTasks() {
    guard !isCancelling else { return }
    isCancelling = true
    Task {
      do {
        try await ManagementService.shared.cancelAllTasks()
        await MainActor.run {
          ErrorManager.shared.notify(message: "All tasks cancelled")
        }
        await loadMetrics()
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        isCancelling = false
      }
    }
  }

  private func processTasksMetrics(_ metric: Metric) async -> (
    [String: Double], [String: Double], [TaskErrorKey: String]
  ) {
    var countByType: [String: Double] = [:]
    var totalTimeByType: [String: Double] = [:]
    var errors: [TaskErrorKey: String] = [:]
    var countErrorCount = 0
    var timeErrorCount = 0

    guard let typeTag = metric.availableTags?.first(where: { $0.tag == "type" }) else {
      return (countByType, totalTimeByType, errors)
    }

    for taskType in typeTag.values {
      do {
        let taskMetric = try await ManagementService.shared.getMetric(
          metric.name, tags: [MetricTag(key: "type", value: taskType)])

        if let count = taskMetric.measurements.first(where: { $0.statistic == "COUNT" })?.value {
          countByType[taskType] = count
        } else {
          countErrorCount += 1
        }
        if let totalTime = taskMetric.measurements.first(where: { $0.statistic == "TOTAL_TIME" })?
          .value
        {
          totalTimeByType[taskType] = totalTime
        } else {
          timeErrorCount += 1
        }
      } catch {
        // Track errors for individual task types
        countErrorCount += 1
        timeErrorCount += 1
        continue
      }
    }

    if countErrorCount > 0 {
      errors[.tasksExecuted] =
        "Failed to load count metrics for \(countErrorCount) task type\(countErrorCount == 1 ? "" : "s")"
    }
    if timeErrorCount > 0 {
      errors[.tasksTotalTime] =
        "Failed to load time metrics for \(timeErrorCount) task type\(timeErrorCount == 1 ? "" : "s")"
    }

    return (countByType, totalTimeByType, errors)
  }

  private func formatNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
  }
}

// MARK: - Data Structures

enum TaskErrorKey: Hashable {
  case tasksExecuted
  case tasksTotalTime
}
