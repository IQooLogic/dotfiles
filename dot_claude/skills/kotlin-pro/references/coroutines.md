# Coroutine Patterns

## Structured Concurrency

Every coroutine must have a defined scope that controls its lifetime. When the scope
is cancelled, all child coroutines are cancelled.

```kotlin
// ViewModel scope — cancelled when ViewModel is cleared
viewModelScope.launch {
    val data = repository.fetchData()
    _uiState.value = UiState.Success(data)
}

// Lifecycle scope — cancelled when lifecycle reaches DESTROYED
lifecycleScope.launch {
    repeatOnLifecycle(Lifecycle.State.STARTED) {
        viewModel.uiState.collect { state ->
            // Only active when lifecycle is STARTED or above
        }
    }
}
```

### Rules
- Never use `GlobalScope` — always use a structured scope
- `viewModelScope` for ViewModel work
- `lifecycleScope` + `repeatOnLifecycle` for lifecycle-aware collection
- Custom scopes via `CoroutineScope(SupervisorJob() + Dispatchers.IO)` when needed

## Dispatchers

| Dispatcher | Use For | Thread Pool |
|-----------|---------|-------------|
| `Dispatchers.Main` | UI updates, state emission | Main thread only |
| `Dispatchers.IO` | Network, disk, database | Shared, expandable |
| `Dispatchers.Default` | CPU-intensive computation | Fixed, CPU cores |
| `Dispatchers.Main.immediate` | Skip dispatch if already on Main | Main thread |

```kotlin
class EventRepository @Inject constructor(
    private val api: EventApi,
    private val dao: EventDao,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) {
    suspend fun fetchAndCache(): List<Event> = withContext(ioDispatcher) {
        val remote = api.fetchEvents()
        dao.upsertAll(remote.map { it.toEntity() })
        remote.map { it.toDomain() }
    }
}
```

### Rules
- Switch dispatchers with `withContext()` — never `launch(Dispatchers.IO)`
- Inject dispatchers for testability: `@IoDispatcher`, `@DefaultDispatcher`
- Never block on `Dispatchers.Main` — no `Thread.sleep`, no sync I/O
- Repository/data source methods handle their own dispatcher switching

## Flow Patterns

### StateFlow vs SharedFlow

```kotlin
// StateFlow — always has a current value, replays last value to new collectors
private val _uiState = MutableStateFlow<UiState>(UiState.Loading)
val uiState: StateFlow<UiState> = _uiState.asStateFlow()

// SharedFlow — no initial value, configurable replay
private val _events = MutableSharedFlow<UiEvent>(
    replay = 0,
    extraBufferCapacity = 1,
    onBufferOverflow = BufferOverflow.DROP_OLDEST
)
val events: SharedFlow<UiEvent> = _events.asSharedFlow()
```

| Type | Initial Value | Replay | Use Case |
|------|--------------|--------|----------|
| `StateFlow` | Required | Last value (1) | UI state, current value |
| `SharedFlow` | None | Configurable | Events, commands |
| `Channel` | None | None | One-shot events (exactly-once delivery) |

### Flow Operators

```kotlin
// Transform
repository.observeEvents()
    .map { entities -> entities.map { it.toDomain() } }
    .distinctUntilChanged()
    .catch { e -> emit(emptyList()) }
    .flowOn(Dispatchers.Default)

// Combine multiple flows
combine(
    repository.observeEvents(),
    filterFlow,
    sortFlow,
) { events, filter, sort ->
    events
        .filter { filter.matches(it) }
        .sortedWith(sort.comparator)
}

// Debounce for search
searchQuery
    .debounce(300)
    .filter { it.length >= 2 }
    .distinctUntilChanged()
    .flatMapLatest { query -> repository.search(query) }
```

### Rules
- Use `flowOn()` to switch dispatcher for upstream operations
- `catch` only catches upstream exceptions
- `distinctUntilChanged()` to avoid redundant emissions
- `flatMapLatest` for search — cancels previous search on new input

## Error Handling in Coroutines

```kotlin
// SupervisorJob — child failure doesn't cancel siblings
val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

// CoroutineExceptionHandler — last resort
val handler = CoroutineExceptionHandler { _, exception ->
    Timber.e(exception, "Uncaught coroutine exception")
}

scope.launch(handler) {
    // If this throws, handler catches it
    // Sibling coroutines continue running
}
```

### Rules
- Use `SupervisorJob` when child failures should be independent
- `try/catch` inside `launch` for recoverable errors
- `CoroutineExceptionHandler` for logging uncaught exceptions
- Never silently swallow exceptions in coroutines

## Testing Coroutines

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class EventViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private lateinit var viewModel: EventViewModel

    @Test
    fun `loads events on init`() = runTest {
        val fakeRepo = FakeEventRepository(listOf(testEvent))
        viewModel = EventViewModel(GetEventsUseCase(fakeRepo))

        // Turbine for Flow testing
        viewModel.uiState.test {
            assertThat(awaitItem()).isEqualTo(UiState.Loading)
            assertThat(awaitItem()).isEqualTo(UiState.Success(listOf(testEvent)))
        }
    }
}

// MainDispatcherRule replaces Main dispatcher with TestDispatcher
class MainDispatcherRule(
    private val dispatcher: TestDispatcher = UnconfinedTestDispatcher()
) : TestWatcher() {
    override fun starting(description: Description) {
        Dispatchers.setMain(dispatcher)
    }
    override fun finished(description: Description) {
        Dispatchers.resetMain()
    }
}
```

### Testing Rules
- Always use `runTest` for coroutine tests
- Replace `Dispatchers.Main` with `MainDispatcherRule`
- Use Turbine (`app.cash.turbine`) for testing Flows
- Inject test dispatchers into classes under test
- `UnconfinedTestDispatcher` for immediate execution
- `StandardTestDispatcher` for controlling advancement

## Advanced Patterns

### Parallel Processing with async/awaitAll

```kotlin
// Process a list of items concurrently, collecting all results
suspend fun processInParallel(items: List<Item>): List<Result> =
    coroutineScope {
        items.map { item ->
            async { process(item) }
        }.awaitAll()
    }
```

### Retry Operator for Robust Flows

```kotlin
// Retry transient failures with condition-based filtering
fun getDataFlow(): Flow<Data> = flow {
    emit(api.getData())
}.retry(3) { cause ->
    cause is IOException
}.catch { e ->
    emit(Data.Error(e))
}
```

### Sequences for Lazy Evaluation

```kotlin
// Use sequence for lazy, short-circuiting collection processing
fun processLargeList(items: List<Item>): List<Result> =
    items.asSequence()
        .filter { it.isValid }
        .map { transform(it) }
        .take(100)
        .toList() // Only processes first 100 valid items
```

### Channel Producer-Consumer

```kotlin
// Channel-based producer for backpressure-aware streaming
fun CoroutineScope.produceNumbers() = produce {
    repeat(10) {
        send(it)
        delay(100)
    }
}
```

### Rules
- `awaitAll()` fails fast — if any async throws, all siblings are cancelled
- Use `retry` only for transient failures (I/O, network) — not logic errors
- Prefer `asSequence()` over intermediate lists for large collections with chained operators
- Use channels for fan-out/fan-in patterns; prefer Flow for most reactive streams
