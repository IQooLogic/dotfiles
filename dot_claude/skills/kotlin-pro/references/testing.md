# Kotlin/Android Testing Patterns

## Unit Tests (JUnit 5 + MockK)

```kotlin
class EventProcessorTest {

    private val repository = mockk<EventRepository>()
    private val processor = EventProcessor(repository)

    @Test
    fun `processes valid event and persists it`() = runTest {
        val event = testEvent()
        coEvery { repository.save(any()) } returns event

        val result = processor.process(event)

        assertThat(result.status).isEqualTo(Status.PROCESSED)
        coVerify { repository.save(event) }
    }

    @Test
    fun `rejects event with missing source`() = runTest {
        val event = testEvent(source = null)

        assertThrows<ValidationException> {
            processor.process(event)
        }
    }
}
```

### MockK Rules
- `mockk<T>()` for mocks, `spyk<T>()` for spies
- `coEvery` / `coVerify` for suspend functions
- `every` / `verify` for regular functions
- `relaxed = true` for mocks that return defaults
- Prefer fakes over mocks for repositories and data sources

## ViewModel Testing

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class EventListViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private val fakeRepository = FakeEventRepository()

    @Test
    fun `emits loading then success on init`() = runTest {
        fakeRepository.setEvents(listOf(testEvent()))
        val viewModel = EventListViewModel(GetEventsUseCase(fakeRepository))

        viewModel.uiState.test {
            assertThat(awaitItem()).isEqualTo(EventListUiState.Loading)
            val success = awaitItem() as EventListUiState.Success
            assertThat(success.events).hasSize(1)
        }
    }

    @Test
    fun `emits error when repository fails`() = runTest {
        fakeRepository.setShouldFail(true)
        val viewModel = EventListViewModel(GetEventsUseCase(fakeRepository))

        viewModel.uiState.test {
            assertThat(awaitItem()).isEqualTo(EventListUiState.Loading)
            assertThat(awaitItem()).isInstanceOf(EventListUiState.Error::class.java)
        }
    }
}
```

### ViewModel Testing Rules
- Test ViewModels through their public `StateFlow` / `SharedFlow`
- Use `Turbine` for Flow assertions — never `first()` or `take()`
- Use fakes, not mocks, for repositories
- Always include `MainDispatcherRule`

## Compose UI Testing

```kotlin
class EventListScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun `displays events when state is success`() {
        val events = listOf(
            EventUi(id = "1", title = "Event 1", source = "webhook"),
            EventUi(id = "2", title = "Event 2", source = "api"),
        )

        composeTestRule.setContent {
            MyProjectTheme {
                EventListScreen(
                    state = EventListUiState.Success(events),
                    onAction = {},
                )
            }
        }

        composeTestRule.onNodeWithText("Event 1").assertIsDisplayed()
        composeTestRule.onNodeWithText("Event 2").assertIsDisplayed()
    }

    @Test
    fun `shows loading indicator when loading`() {
        composeTestRule.setContent {
            MyProjectTheme {
                EventListScreen(
                    state = EventListUiState.Loading,
                    onAction = {},
                )
            }
        }

        composeTestRule.onNodeWithTag("loading_indicator").assertIsDisplayed()
    }

    @Test
    fun `calls delete action when delete button clicked`() {
        var capturedAction: EventListAction? = null

        composeTestRule.setContent {
            MyProjectTheme {
                EventListScreen(
                    state = EventListUiState.Success(listOf(testEventUi())),
                    onAction = { capturedAction = it },
                )
            }
        }

        composeTestRule.onNodeWithContentDescription("Delete").performClick()
        assertThat(capturedAction).isEqualTo(EventListAction.Delete("1"))
    }
}
```

### Compose Testing Rules
- Test composables with explicit state — never with ViewModels
- Use `testTag` for elements that lack accessible text
- `assertIsDisplayed()`, `performClick()`, `performTextInput()`
- Test interaction callbacks via captured lambdas
- Screenshot tests with Roborazzi or Paparazzi for visual regression

## Fake Implementations

```kotlin
class FakeEventRepository : EventRepository {
    private val events = MutableStateFlow<List<Event>>(emptyList())
    private var shouldFail = false

    fun setEvents(list: List<Event>) { events.value = list }
    fun setShouldFail(fail: Boolean) { shouldFail = fail }

    override fun observeEvents(): Flow<List<Event>> {
        if (shouldFail) return flow { throw IOException("Fake error") }
        return events
    }

    override suspend fun save(event: Event): Event {
        if (shouldFail) throw IOException("Fake error")
        events.value = events.value + event
        return event
    }
}
```

### Rules
- Fakes implement the real interface with in-memory state
- Configurable failure modes for error path testing
- Prefer fakes over mocks for data layer interfaces
- Fakes live in `test/` source set, shared across test classes

## Instrumented Tests (Android)

```kotlin
@HiltAndroidTest
@RunWith(AndroidJUnit4::class)
class EventFlowTest {

    @get:Rule(order = 0)
    val hiltRule = HiltAndroidRule(this)

    @get:Rule(order = 1)
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    @Inject
    lateinit var database: AppDatabase

    @Before
    fun setup() {
        hiltRule.inject()
        database.clearAllTables()
    }

    @Test
    fun createAndViewEvent() {
        // Navigate to create
        composeTestRule.onNodeWithText("Create Event").performClick()

        // Fill form
        composeTestRule.onNodeWithTag("source_input").performTextInput("webhook")
        composeTestRule.onNodeWithTag("submit_button").performClick()

        // Verify on list
        composeTestRule.onNodeWithText("webhook").assertIsDisplayed()
    }
}
```

### Instrumented Test Rules
- Use Hilt testing for DI in instrumented tests
- Clear database in `@Before` — tests must be independent
- Use `createAndroidComposeRule` for full activity tests
- Keep instrumented tests focused — prefer unit tests where possible
- Tag: `@LargeTest` for long-running, `@MediumTest` for moderate

## Test Fixtures

```kotlin
object TestFixtures {
    fun testEvent(
        id: String = UUID.randomUUID().toString(),
        source: String? = "webhook",
        timestamp: Instant = Instant.now(),
    ) = Event(id = id, source = source, timestamp = timestamp)

    fun testEventUi(
        id: String = "1",
        title: String = "Test Event",
        source: String = "webhook",
    ) = EventUi(id = id, title = title, source = source)
}
```

- Default-parameter factories for test data
- Separate fixtures for domain models and UI models
- Deterministic defaults — never random unless testing randomness
