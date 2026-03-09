# Android Architecture Patterns

## Clean Architecture Layers

```
UI Layer (Compose)  →  Domain Layer  ←  Data Layer
  - Screens             - Use Cases       - Repositories (impl)
  - ViewModels          - Models          - Data Sources
  - UI State            - Repository IF   - Mappers
```

- **Domain layer has zero Android dependencies** — pure Kotlin
- Data flows: UI observes ViewModel → ViewModel calls UseCase → UseCase calls Repository
- Dependencies point inward: UI → Domain ← Data

## ViewModel Pattern

```kotlin
@HiltViewModel
class EventListViewModel @Inject constructor(
    private val getEvents: GetEventsUseCase,
    private val savedStateHandle: SavedStateHandle,
) : ViewModel() {

    private val _uiState = MutableStateFlow<EventListUiState>(EventListUiState.Loading)
    val uiState: StateFlow<EventListUiState> = _uiState.asStateFlow()

    // One-shot events (navigation, snackbar)
    private val _events = Channel<UiEvent>(Channel.BUFFERED)
    val events: Flow<UiEvent> = _events.receiveAsFlow()

    init {
        loadEvents()
    }

    fun onAction(action: EventListAction) {
        when (action) {
            is EventListAction.Refresh -> loadEvents()
            is EventListAction.Delete -> deleteEvent(action.id)
        }
    }

    private fun loadEvents() {
        viewModelScope.launch {
            _uiState.value = EventListUiState.Loading
            getEvents()
                .catch { e ->
                    _uiState.value = EventListUiState.Error(e.message ?: "Unknown error")
                }
                .collect { events ->
                    _uiState.value = EventListUiState.Success(events)
                }
        }
    }
}
```

### Rules
- One ViewModel per screen
- Expose `StateFlow` for UI state — never `LiveData` in new code
- Use `Channel` for one-shot events (navigation, toasts)
- Single `onAction(Action)` entry point for all user interactions
- Never expose `MutableStateFlow` publicly

## UI State Modeling

```kotlin
sealed interface EventListUiState {
    data object Loading : EventListUiState
    data class Success(val events: List<EventUi>) : EventListUiState
    data class Error(val message: String) : EventListUiState
}

sealed interface EventListAction {
    data object Refresh : EventListAction
    data class Delete(val id: String) : EventListAction
}

sealed interface UiEvent {
    data class ShowSnackbar(val message: String) : UiEvent
    data class Navigate(val route: String) : UiEvent
}
```

- Sealed interfaces for state — exhaustive `when` checks
- Separate state (what to display) from events (what to do once)
- UI state is a snapshot — never partial updates

## Use Cases

```kotlin
class GetEventsUseCase @Inject constructor(
    private val repository: EventRepository,
) {
    operator fun invoke(): Flow<List<Event>> {
        return repository.observeEvents()
            .map { events -> events.sortedByDescending { it.timestamp } }
    }
}
```

- One public method per use case (`operator fun invoke()`)
- Use cases orchestrate — they don't contain framework code
- Return `Flow` for observable data, `Result` for one-shot operations

## Navigation

```kotlin
// Routes as a sealed hierarchy
sealed class Route(val path: String) {
    data object EventList : Route("events")
    data class EventDetail(val id: String) : Route("events/{id}") {
        companion object {
            const val ROUTE = "events/{id}"
        }
    }
}

@Composable
fun AppNavHost(navController: NavHostController = rememberNavController()) {
    NavHost(navController = navController, startDestination = Route.EventList.path) {
        composable(Route.EventList.path) {
            val viewModel: EventListViewModel = hiltViewModel()
            val state by viewModel.uiState.collectAsStateWithLifecycle()
            EventListScreen(
                state = state,
                onAction = viewModel::onAction,
                onNavigateToDetail = { id ->
                    navController.navigate("events/$id")
                }
            )
        }
        composable(
            route = Route.EventDetail.ROUTE,
            arguments = listOf(navArgument("id") { type = NavType.StringType })
        ) { backStackEntry ->
            val viewModel: EventDetailViewModel = hiltViewModel()
            val state by viewModel.uiState.collectAsStateWithLifecycle()
            EventDetailScreen(state = state)
        }
    }
}
```

## Lifecycle-Aware Collection

```kotlin
// In Compose — preferred
@Composable
fun EventListScreen(viewModel: EventListViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    // One-shot events
    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is UiEvent.ShowSnackbar -> { /* show snackbar */ }
                is UiEvent.Navigate -> { /* navigate */ }
            }
        }
    }
}
```

- Always use `collectAsStateWithLifecycle()` in Compose — never plain `collectAsState()`
- `LaunchedEffect` for one-shot event collection

## Room Database

```kotlin
@Entity(tableName = "events")
data class EventEntity(
    @PrimaryKey val id: String,
    val source: String,
    val payload: String,
    val timestamp: Long,
)

@Dao
interface EventDao {
    @Query("SELECT * FROM events ORDER BY timestamp DESC")
    fun observeAll(): Flow<List<EventEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(event: EventEntity)

    @Delete
    suspend fun delete(event: EventEntity)
}

@Database(entities = [EventEntity::class], version = 1)
abstract class AppDatabase : RoomDatabase() {
    abstract fun eventDao(): EventDao
}
```

### Rules
- Entity classes are data layer only — never expose to UI
- Use `Flow` return types for observable queries
- `suspend` functions for write operations
- Provide migrations for schema changes — never `fallbackToDestructiveMigration()` in production

## Hilt Modules

```kotlin
@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase {
        return Room.databaseBuilder(context, AppDatabase::class.java, "app.db")
            .build()
    }

    @Provides
    fun provideEventDao(db: AppDatabase): EventDao = db.eventDao()
}

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(client: OkHttpClient): Retrofit {
        return Retrofit.Builder()
            .baseUrl(BuildConfig.API_BASE_URL)
            .client(client)
            .addConverterFactory(MoshiConverterFactory.create())
            .build()
    }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds
    @Singleton
    abstract fun bindEventRepository(impl: EventRepositoryImpl): EventRepository
}
```

- `@Provides` for third-party classes (Room, Retrofit, OkHttp)
- `@Binds` for interface-to-implementation bindings
- `SingletonComponent` for app-wide singletons
- `ViewModelComponent` for ViewModel-scoped dependencies
