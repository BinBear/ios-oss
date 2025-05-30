import KsApi
import Prelude
import ReactiveSwift

public protocol DiscoveryFiltersViewModelInputs {
  /// Call with the row that is selected when the filters appear and array of loaded categories.
  func configureWith(selectedRow: SelectableRow)

  /// Call when an expandable row is tapped.
  func tapped(expandableRow: ExpandableRow)

  /// Call when a selectable row is tapped.
  func tapped(selectableRow: SelectableRow)

  /// Call when the view loads.
  func viewDidLoad()

  /// Call when the view did appear.
  func viewDidAppear()
}

public protocol DiscoveryFiltersViewModelOutputs {
  /// Emits when to animate in the view.
  var animateInView: Signal<(), Never> { get }

  /// Emits whether the categories are loading for the activity indicator view.
  var loadingIndicatorIsVisible: Signal<Bool, Never> { get }

  /**
   Emits an array of expandable rows to put into the categories section of filters,
   a category id to set row styles, and an optional category id for setting scrollTo position.
   **/
  var loadCategoryRows: Signal<
    (rows: [ExpandableRow], categoryId: Int?, selectedRowId: Int?),
    Never
  > { get }

  /// Emits an array of selectable rows for the favorites section and category id to set row styles.
  var loadFavoriteRows: Signal<(rows: [SelectableRow], categoryId: Int?), Never> { get }

  /// Emits an array of selectable rows to put into the top filters section and category id to set row styles.
  var loadTopRows: Signal<(rows: [SelectableRow], categoryId: Int?), Never> { get }

  /// Emits a selectable row when the delegate should be notified of the selection.
  var notifyDelegateOfSelectedRow: Signal<SelectableRow, Never> { get }

  /// A bool that determines whether a cell should be animated when it is displayed.
  var shouldAnimateSelectableCell: Bool { get }
}

public protocol DiscoveryFiltersViewModelType {
  var inputs: DiscoveryFiltersViewModelInputs { get }
  var outputs: DiscoveryFiltersViewModelOutputs { get }
}

public final class DiscoveryFiltersViewModel: DiscoveryFiltersViewModelType,
  DiscoveryFiltersViewModelInputs, DiscoveryFiltersViewModelOutputs {
  public init() {
    let initialTopFilters = self.viewDidLoadProperty.signal
      .take(first: 1)
      .map { _ in topFilters(forUser: AppEnvironment.current.currentUser) }

    let initialSelectedRow = Signal.combineLatest(
      self.initialSelectedRowProperty.signal.skipNil(),
      self.viewDidLoadProperty.signal
    )
    .take(first: 1)
    .map(first)

    let topRows = Signal.combineLatest(
      initialTopFilters,
      initialSelectedRow
    )
    .map { params, selectedRow -> [SelectableRow] in
      params.map { p in SelectableRow(isSelected: p == selectedRow.params, params: p) }
    }

    self.categoriesUseCase = FetchCategoriesUseCase(initialSignal: self.viewDidLoadProperty.signal)

    let categoryId = self.initialSelectedRowProperty.signal.skipNil()
      .map { $0.params.category?.rootId }

    self.loadTopRows = Signal.combineLatest(topRows, categoryId)
      .map { (rows: $0, categoryId: $1) }

    let selectedRowWithCategories = Signal.combineLatest(
      initialSelectedRow,
      self.categoriesUseCase.categories
    )

    let favoriteRows = selectedRowWithCategories
      .map(favorites(selectedRow:categories:))
      .skipNil()

    self.loadFavoriteRows = Signal.combineLatest(favoriteRows, categoryId)
      .map { (rows: $0, categoryId: $1) }

    let selectedRowId = Signal.merge(
      categoryId,
      self.tappedExpandableRowProperty.signal.skipNil().map { $0.params.category?.rootId }
    )

    let initialRows = selectedRowWithCategories
      .map(expandableRows(selectedRow:categories:))

    let expandingRows = Signal.combineLatest(
      self.tappedExpandableRowProperty.signal.skipNil(),
      initialRows
    )
    .map(toggleExpansion(row:in:))

    let initialCatRowsAndIdAndSelectedRowId = Signal.combineLatest(categoryId, selectedRowId)
      .takePairWhen(initialRows)

    let expandedCatRowsAndIdAndSelectedRowId = Signal.combineLatest(categoryId, selectedRowId)
      .takePairWhen(expandingRows)

    self.loadCategoryRows = Signal.merge(
      initialCatRowsAndIdAndSelectedRowId,
      expandedCatRowsAndIdAndSelectedRowId
    )
    .map { (rows: $1, categoryId: $0.0, selectedRowId: $0.1) }

    self.notifyDelegateOfSelectedRow = self.tappedSelectableRowProperty.signal.skipNil()

    self.shouldAnimateSelectableCellProperty <~ Signal.merge(
      self.tappedExpandableRowProperty.signal.mapConst(true),

      self.tappedExpandableRowProperty.signal
        .ksr_delay(.milliseconds(300), on: AppEnvironment.current.scheduler)
        .mapConst(false)
    )

    self.animateInView = self.viewDidAppearProperty.signal

    self.notifyDelegateOfSelectedRow
      .observeValues {
        AppEnvironment.current.ksrAnalytics.trackDiscoveryModalSelectedFilter(
          params: $0.params,
          typeContext: typeContext(from: $0.params),
          locationContext: .discoverOverlay
        )
      }
  }

  fileprivate let initialSelectedRowProperty = MutableProperty<SelectableRow?>(nil)
  public func configureWith(selectedRow: SelectableRow) {
    self.initialSelectedRowProperty.value = selectedRow
  }

  fileprivate let tappedExpandableRowProperty = MutableProperty<ExpandableRow?>(nil)
  public func tapped(expandableRow: ExpandableRow) {
    self.tappedExpandableRowProperty.value = expandableRow
  }

  fileprivate let tappedSelectableRowProperty = MutableProperty<SelectableRow?>(nil)
  public func tapped(selectableRow: SelectableRow) {
    self.tappedSelectableRowProperty.value = selectableRow
  }

  fileprivate let viewDidLoadProperty = MutableProperty(())
  public func viewDidLoad() {
    self.viewDidLoadProperty.value = ()
  }

  fileprivate let viewDidAppearProperty = MutableProperty(())
  public func viewDidAppear() {
    self.viewDidAppearProperty.value = ()
  }

  fileprivate let shouldAnimateSelectableCellProperty = MutableProperty(false)
  public var shouldAnimateSelectableCell: Bool {
    return self.shouldAnimateSelectableCellProperty.value
  }

  public let animateInView: Signal<(), Never>
  public var loadingIndicatorIsVisible: Signal<Bool, Never> {
    self.categoriesUseCase.loadingIndicatorIsVisible
  }

  public let loadCategoryRows: Signal<
    (rows: [ExpandableRow], categoryId: Int?, selectedRowId: Int?),
    Never
  >
  public let loadFavoriteRows: Signal<(rows: [SelectableRow], categoryId: Int?), Never>
  public let loadTopRows: Signal<(rows: [SelectableRow], categoryId: Int?), Never>
  public let notifyDelegateOfSelectedRow: Signal<SelectableRow, Never>

  private let categoriesUseCase: FetchCategoriesUseCase

  public var inputs: DiscoveryFiltersViewModelInputs { return self }
  public var outputs: DiscoveryFiltersViewModelOutputs { return self }
}

/**
 Converts an array of categories into a grouped array of expandable rows,
 then finds the expandable row that contains the given selectable row, and expands it.

 - parameter selectedRow: An optional selected row to search for.

 - parameter categories: A full array of categories.

 - returns: An array of expandable rows with one row expanded.
 */

private func expandableRows(
  selectedRow: SelectableRow,
  categories: [KsApi.Category]
) -> [ExpandableRow] {
  let expandableRows = categories.filter { (category: KsApi.Category) in category.isRoot }
    .sorted { (lhs: KsApi.Category, _) in lhs.isRoot }
    .map { (rootCategory: KsApi.Category) in
      ExpandableRow(
        isExpanded: false,
        params: .defaults |> DiscoveryParams.lens.category .~ rootCategory,
        selectableRows: ([rootCategory] + (rootCategory.subcategories?.nodes ?? []))
          .sorted()
          .compactMap { (node: KsApi.Category) in
            SelectableRow(
              isSelected: node == selectedRow.params.category,
              params: .defaults
                |> DiscoveryParams.lens.category .~ node
            )
          }
      )
    }
    .sorted { (lhs: ExpandableRow, rhs: ExpandableRow) in
      guard let lhsCategory = lhs.params.category, let rhsCategory = rhs.params.category else {
        return lhs.params.category == nil
      }
      return lhsCategory < rhsCategory
    }

  return expandableRows.map { expandableRow in
    expandableRow
      |> ExpandableRow.lens.isExpanded .~
      expandableRow.selectableRows.lazy.map { $0.params }.contains(selectedRow.params)
      |> ExpandableRow.lens.selectableRows .~
      expandableRow.selectableRows.sorted { lhs, rhs in
        guard let lhsName = lhs.params.category?.name, let rhsName = rhs.params.category?.name,
              lhs.params.category?.isRoot == rhs.params.category?.isRoot else {
          return (lhs.params.category?.isRoot ?? false) && !(rhs.params.category?.isRoot ?? false)
        }
        return lhsName < rhsName
      }
  }
}

/**
 Toggles the expansion of the row provided.

 - parameter rowToToggle:    The row to toggle expansion.
 - parameter expandableRows: A full array of expandable rows.

 - returns: A new array of expandable rows with the provided row's expansion toggled.
 */
private func toggleExpansion(
  row rowToToggle: ExpandableRow,
  in expandableRows: [ExpandableRow]
) -> [ExpandableRow] {
  return expandableRows
    .map { expandableRow in

      expandableRow
        |> ExpandableRow.lens.isExpanded .~ (
          expandableRow.params == rowToToggle.params &&
            !rowToToggle.isExpanded
        )
    }
}

private func topFilters(forUser user: User?) -> [DiscoveryParams] {
  var filters: [DiscoveryParams] = []

  filters.append(.defaults |> DiscoveryParams.lens.includePOTD .~ true)
  filters.append(.defaults |> DiscoveryParams.lens.staffPicks .~ true)

  guard user != nil else {
    return filters
  }

  filters.append(.defaults |> DiscoveryParams.lens.starred .~ true)

  if user?.optedOutOfRecommendations != true {
    filters.append(
      .defaults
        |> DiscoveryParams.lens.recommended .~ true
        |> DiscoveryParams.lens.backed .~ false
    )
  }

  filters.append(.defaults |> DiscoveryParams.lens.social .~ true)

  return filters
}

private func favorites(selectedRow: SelectableRow, categories: [KsApi.Category])
  -> [SelectableRow]? {
  let subcategories = categories
    .filter { $0.isRoot }
    .flatMap { category in [category] + (category.subcategories?.nodes ?? []) }

  let faves: [SelectableRow] = subcategories
    .compactMap { subcategory in
      guard let id = subcategory.intID else {
        return nil
      }
      if AppEnvironment.current.ubiquitousStore.favoriteCategoryIds.contains(id) ||
        AppEnvironment.current.userDefaults.favoriteCategoryIds.contains(id) {
        return SelectableRow(
          isSelected: subcategory == selectedRow.params.category,
          params: .defaults |> DiscoveryParams.lens.category .~ subcategory
        )
      } else {
        return nil
      }
    }
  return faves.isEmpty ? nil : faves
}

private func typeContext(
  from discoveryParams: DiscoveryParams
) -> KSRAnalytics.TypeContext {
  if discoveryParams.staffPicks == true {
    return .pwl
  } else if discoveryParams.starred == true {
    return .watched
  } else if discoveryParams.social == true {
    return .social
  } else if let category = discoveryParams.category {
    return category.parent == nil ? .categoryName : .subcategoryName
  } else if discoveryParams.recommended == true {
    return .recommended
  } else {
    return .allProjects
  }
}
