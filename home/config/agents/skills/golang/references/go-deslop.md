# Go Codebase Cleanup: Remove Defensive Over-Engineering and AI Slop

Audit this Go codebase and aggressively simplify AI-generated, defensive, overly abstract, or unnecessarily generic code.

The goal is to make the code look like it was written by an experienced Go engineer:

- simple
- explicit
- strongly typed
- boring
- idiomatic
- easy to trace
- minimal abstraction
- minimal magic

Do not optimize for cleverness.

Do not replace simple code with frameworks, generic helpers, reflection, interfaces, factories, adapters, builders, or excessive layering.

The primary rule is:

> **Validate untrusted data at the boundary. Use concrete types everywhere else.**

---

# 1. Remove unnecessary `any` and `interface{}`

Search aggressively for:

```go
any
interface{}
map[string]any
map[string]interface{}
```

Ask why the value is untyped.

Bad:

```go
func getDomain(data map[string]any) string {
	value, ok := data["domain"]
	if !ok {
		return ""
	}

	domain, ok := value.(string)
	if !ok {
		return ""
	}

	return domain
}
```

Prefer:

```go
type DomainEvent struct {
	Domain string `json:"domain"`
}
```

Then:

```go
event.Domain
```

Do not carry generic maps through the application and repeatedly recover types from them.

If the JSON shape is known, unmarshal directly into a struct.

---

# 2. Stop creating generic conversion helpers

Be suspicious of functions like:

```go
toString()
asString()
stringValue()
safeString()
toInt()
asInt()
toBool()
toMap()
asMap()
getString()
getOptionalString()
valueOrDefault()
```

Bad:

```go
func toString(value any) string {
	switch v := value.(type) {
	case string:
		return v
	case int:
		return strconv.Itoa(v)
	case int64:
		return strconv.FormatInt(v, 10)
	case fmt.Stringer:
		return v.String()
	case nil:
		return ""
	default:
		return fmt.Sprintf("%v", v)
	}
}
```

Ask instead:

> What type is this value actually supposed to be?

If it is a string:

```go
func normalizeDomain(domain string) string {
	return strings.ToLower(strings.TrimSpace(domain))
}
```

Do not accept `any` just to make a helper "flexible."

---

# 3. Remove fallback-to-zero-value programming

Search for code that silently converts invalid states into:

```go
""
0
false
nil
[]T{}
map[K]V{}
```

Examples:

```go
if value == nil {
	return ""
}
```

```go
if err != nil {
	return nil
}
```

```go
if project == nil {
	return &Project{}
}
```

Do not hide invalid states.

If data is required, return an error.

Bad:

```go
func projectID(project *Project) string {
	if project == nil {
		return ""
	}

	return project.ID
}
```

Prefer fixing the caller so `project` cannot be nil there.

Or, if absence is genuinely possible:

```go
if project == nil {
	return ErrProjectNotFound
}
```

Validate/narrow once, then continue with clean code.

---

# 4. Do not add nil checks everywhere

Nil checks should correspond to actual nullable states.

Bad:

```go
func handleProject(project *Project) error {
	if project == nil {
		return errors.New("project is nil")
	}

	if project.Config == nil {
		return errors.New("project config is nil")
	}

	if project.Config.Domain == nil {
		return errors.New("domain is nil")
	}

	// actual logic
}
```

If those fields are required by the application model, redesign the types instead.

Prefer:

```go
type Project struct {
	Config ProjectConfig
}

type ProjectConfig struct {
	Domain string
}
```

Then:

```go
project.Config.Domain
```

Do not represent required values as pointers merely because Go allows pointers.

---

# 5. Stop using pointers for everything

Review struct fields like:

```go
*string
*bool
*int
*time.Time
```

Do not use pointers merely to distinguish "missing" from zero unless the distinction actually matters.

Bad:

```go
type Config struct {
	Enabled *bool
	Port    *int
	Name    *string
}
```

If those values are required:

```go
type Config struct {
	Enabled bool
	Port    int
	Name    string
}
```

Pointers should communicate real optionality or identity/mutation semantics.

---

# 6. Remove pointless helper extraction

Do not create a helper for every 2–3 lines.

Be suspicious of:

```go
getDomainID()
extractProjectID()
resolveName()
buildKey()
parseValue()
stringFrom()
domainFrom()
```

when the helper:

- has one caller
- only accesses a field
- only checks nil
- only calls `strings.TrimSpace`
- only calls `.String()`
- only performs a type assertion
- only forwards arguments

Bad:

```go
func domainIDFrom(record *DNSRecord) string {
	if record == nil {
		return ""
	}

	return record.DomainID.String()
}
```

Prefer:

```go
record.DomainID.String()
```

provided `record` is already known to exist.

A helper should represent a real reusable concept, not hide straightforward code.

---

# 7. Do not introduce interfaces without a real reason

Go interfaces should usually be defined by the consumer and kept small.

Be suspicious of:

```go
type ProjectService interface {
	CreateProject(...)
	GetProject(...)
	UpdateProject(...)
	DeleteProject(...)
	ListProjects(...)
	ValidateProject(...)
	SyncProject(...)
	RefreshProject(...)
}
```

especially if there is only one implementation.

Do not create an interface merely because "services should have interfaces."

Prefer concrete types unless you genuinely need:

- multiple implementations
- substitution
- testing at that boundary
- plugin behavior
- a narrow consumer contract

Bad:

```go
type DomainManager interface {
	Map(...)
}
```

with only:

```go
type domainManagerImpl struct{}
```

Prefer:

```go
type DomainManager struct{}
```

Do not create Java-style `IFoo` / `FooImpl` architecture in Go.

---

# 8. Keep interfaces small

When an interface is justified, define only what the consumer needs.

Bad:

```go
type Repository interface {
	Create(...)
	Update(...)
	Delete(...)
	Get(...)
	List(...)
	Count(...)
	Exists(...)
	Search(...)
}
```

when a component only needs:

```go
Get(...)
```

Prefer:

```go
type projectGetter interface {
	Get(ctx context.Context, id string) (*Project, error)
}
```

Do not expose giant interfaces just because a concrete repository has many methods.

---

# 9. Remove unnecessary abstraction layers

Look for chains like:

```txt
handler
↓
controller
↓
service
↓
manager
↓
processor
↓
repository
↓
store
↓
database client
```

where most layers simply forward arguments.

Bad:

```go
func (s *Service) GetProject(ctx context.Context, id string) (*Project, error) {
	return s.manager.GetProject(ctx, id)
}
```

and:

```go
func (m *Manager) GetProject(ctx context.Context, id string) (*Project, error) {
	return m.repository.GetProject(ctx, id)
}
```

If these layers do not contain meaningful business logic, remove them.

One meaningful layer is better than five pass-through layers.

---

# 10. Remove pass-through wrappers

Search for functions whose entire body is:

```go
return dependency.Do(...)
```

or:

```go
return helper(value)
```

or:

```go
result, err := dependency.Do(...)
if err != nil {
	return nil, err
}
return result, nil
```

Simplify:

```go
return dependency.Do(...)
```

Do not add wrappers purely to make the architecture look layered.

---

# 11. Simplify redundant error handling

Bad:

```go
result, err := repo.Get(ctx, id)
if err != nil {
	return nil, err
}

return result, nil
```

Prefer:

```go
return repo.Get(ctx, id)
```

Bad:

```go
if err != nil {
	return fmt.Errorf("error: %w", err)
}
```

This adds no useful context.

If wrapping, add meaningful context:

```go
if err != nil {
	return fmt.Errorf("load project %s: %w", id, err)
}
```

But do not mechanically wrap every error at every layer.

An error should not become:

```txt
failed to process project:
failed to get project:
failed to retrieve project:
failed to query project:
sql: no rows
```

Add context where it materially improves debugging.

---

# 12. Do not swallow errors

Find:

```go
if err != nil {
	return nil
}
```

or:

```go
if err != nil {
	log.Println(err)
	return nil
}
```

or:

```go
_ = doSomething()
```

Determine whether ignoring the error is intentional.

Do not turn bugs into silent success.

If an error can safely be ignored, make the reasoning obvious.

Example:

```go
if err := cache.Delete(ctx, key); err != nil {
	logger.Warn("failed to invalidate cache", "key", key, "error", err)
}
```

only when cache invalidation failure genuinely should not fail the operation.

---

# 13. Avoid unnecessary custom error types

Be suspicious of enormous error hierarchies.

Do not create:

```go
type ValidationError struct{}
type RepositoryError struct{}
type ServiceError struct{}
type DomainError struct{}
type InternalError struct{}
```

unless callers actually need different behavior based on the error.

Prefer:

```go
var ErrProjectNotFound = errors.New("project not found")
```

and:

```go
errors.Is(err, ErrProjectNotFound)
```

Use structured custom errors only when they carry meaningful information.

---

# 14. Use `errors.Is` / `errors.As` idiomatically

Do not manually inspect error strings.

Bad:

```go
if strings.Contains(err.Error(), "duplicate") {
```

Prefer the underlying driver's supported error type/code.

Example:

```go
var writeErr mongo.WriteException
if errors.As(err, &writeErr) {
	...
}
```

But do not turn a simple known-driver check into enormous generic error inspection code.

Keep it proportional to the actual need.

---

# 15. Avoid reflection unless it is genuinely necessary

Search for:

```go
reflect.
```

Reflection is suspicious in ordinary business logic.

Bad:

```go
func isEmpty(value any) bool {
	v := reflect.ValueOf(value)
	...
}
```

Prefer explicit typed logic.

Do not use reflection to avoid writing five obvious lines.

Reflection is reasonable in areas such as:

- serializers
- frameworks
- generic libraries
- tooling

It should rarely appear in normal handlers/services/domain logic.

---

# 16. Do not use generics where concrete code is clearer

Go generics are useful, but AI often introduces them for trivial problems.

Be suspicious of:

```go
func Ptr[T any](value T) *T
func ValueOrDefault[T comparable](...)
func ConvertSlice[T any, R any](...)
func SafeCast[T any](...)
func GetOrDefault[K comparable, V any](...)
```

Do not create generic utilities just because two lines look similar.

Prefer concrete domain code where it is easier to understand.

A generic abstraction should solve a real recurring problem.

---

# 17. Remove generic map accessor utilities

Bad:

```go
func GetString(data map[string]any, key string) string
func GetInt(data map[string]any, key string) int
func GetBool(data map[string]any, key string) bool
```

This is usually evidence that structured data should have been decoded into a struct.

Prefer:

```go
type DeploymentEvent struct {
	ProjectID string `json:"project_id"`
	Port      int    `json:"port"`
	Enabled   bool   `json:"enabled"`
}
```

Then use:

```go
event.ProjectID
event.Port
event.Enabled
```

---

# 18. Decode JSON once at the boundary

Bad:

```go
var payload map[string]any

if err := json.Unmarshal(body, &payload); err != nil {
	return err
}

event, _ := payload["event"].(string)
data, _ := payload["data"].(map[string]any)
projectID, _ := data["project_id"].(string)
```

Prefer:

```go
type QueueEvent struct {
	Event string          `json:"event"`
	Data  json.RawMessage `json:"data"`
}
```

Then decode the event-specific payload once:

```go
type ProjectSyncEvent struct {
	ProjectID string `json:"project_id"`
}

var event ProjectSyncEvent

if err := json.Unmarshal(payload.Data, &event); err != nil {
	return fmt.Errorf("decode project sync event: %w", err)
}
```

After decoding, business logic should operate on typed structs.

---

# 19. Avoid `map[string]any` for database models

If MongoDB, JSONB, Redis, or another store returns known document shapes, define structs.

Bad:

```go
var document map[string]any
```

followed by:

```go
id, ok := document["domain"].(primitive.ObjectID)
```

Prefer:

```go
type DNSDocument struct {
	Domain primitive.ObjectID `bson:"domain"`
}
```

Then:

```go
document.Domain.Hex()
```

Fix broad types at the data-access boundary rather than adding extractors everywhere.

---

# 20. Remove fake defensive type assertions

Bad:

```go
value, ok := data.(map[string]any)
if !ok {
	return nil
}

domain, ok := value["domain"].(string)
if !ok {
	return nil
}
```

if the data came from a contract already controlled by the application.

Either:

- type it correctly upstream, or
- genuinely validate it at the external boundary

Do not repeatedly rediscover types inside trusted application code.

---

# 21. Avoid excessive DTO/model duplication

Be suspicious when the same data has:

```go
ProjectRequest
ProjectDTO
ProjectInput
ProjectParams
ProjectData
ProjectModel
ProjectEntity
ProjectResponse
```

with nearly identical fields.

Separate types when the contracts are materially different.

Do not duplicate structs solely because each layer "needs its own model."

If two layers genuinely share the same concept, use the same type.

---

# 22. Remove mapper slop

Look for functions like:

```go
func projectToDTO(project Project) ProjectDTO {
	return ProjectDTO{
		ID:   project.ID,
		Name: project.Name,
	}
}
```

when `ProjectDTO` and `Project` are effectively identical and no boundary requires the distinction.

Do not maintain fleets of:

```txt
toDTO
fromDTO
toModel
fromModel
toEntity
fromEntity
```

without a meaningful difference in representation.

---

# 23. Avoid constructors that do nothing useful

Bad:

```go
func NewProjectService(repo Repository) *ProjectService {
	return &ProjectService{
		repo: repo,
	}
}
```

This constructor can be reasonable if it provides a stable construction API.

But do not add constructors for simple data structs:

```go
func NewDomain(name string) Domain {
	return Domain{Name: name}
}
```

when:

```go
Domain{Name: name}
```

is clearer.

Constructors should establish invariants or hide meaningful setup.

---

# 24. Remove builder-pattern slop

Do not introduce Java-style builders for simple structs.

Bad:

```go
deployment := NewDeploymentBuilder().
	WithProjectID(projectID).
	WithRegion(region).
	WithPort(port).
	WithImage(image).
	Build()
```

Prefer:

```go
deployment := Deployment{
	ProjectID: projectID,
	Region:    region,
	Port:      port,
	Image:     image,
}
```

Builders are justified only when construction is genuinely complex.

---

# 25. Do not overuse functional options

Avoid:

```go
NewService(
	WithRepository(repo),
	WithLogger(logger),
	WithMetrics(metrics),
)
```

when all fields are required.

Prefer:

```go
NewService(repo, logger, metrics)
```

Functional options are useful primarily for optional configuration or APIs with many optional settings.

Do not introduce them just because they are a popular Go pattern.

---

# 26. Avoid unnecessary factories

Bad:

```go
type RepositoryFactory struct{}

func (f *RepositoryFactory) CreateRepository(kind string) Repository
```

when the application has one concrete repository.

Prefer constructing the concrete dependency directly.

Factories should exist because runtime selection is real, not because "factory pattern" sounds architectural.

---

# 27. Avoid unnecessary dependency injection infrastructure

Normal Go dependency injection is usually just:

```go
service := NewService(repo, logger)
```

Do not introduce:

- containers
- service locators
- registries
- providers
- dependency graphs
- reflection-based injection

unless the project genuinely needs them.

Explicit wiring is a strength of Go.

---

# 28. Prefer straightforward control flow

Bad:

```go
var shouldProcess bool

if project != nil {
	if project.Enabled {
		if project.Status == StatusActive {
			shouldProcess = true
		}
	}
}
```

Prefer early returns:

```go
if project == nil {
	return nil
}

if !project.Enabled {
	return nil
}

if project.Status != StatusActive {
	return nil
}

// actual work
```

Or when simple:

```go
shouldProcess := project != nil &&
	project.Enabled &&
	project.Status == StatusActive
```

Choose whichever is easier to read.

Do not optimize for clever one-liners.

---

# 29. Prefer early returns over deep nesting

Bad:

```go
if err == nil {
	if project != nil {
		if project.Enabled {
			// 80 lines
		}
	}
}
```

Prefer:

```go
if err != nil {
	return err
}

if project == nil {
	return ErrProjectNotFound
}

if !project.Enabled {
	return nil
}

// main logic
```

Keep the happy path visually obvious.

---

# 30. Remove useless temporary variables

Bad:

```go
rawDomain := event.Domain
normalizedDomain := strings.TrimSpace(rawDomain)
domain := strings.ToLower(normalizedDomain)
```

Prefer:

```go
domain := strings.ToLower(strings.TrimSpace(event.Domain))
```

But do not compress code so aggressively that readability decreases.

Intermediate variables should represent meaningful concepts.

---

# 32. Remove redundant slice/map initialization

Question code like:

```go
items := make([]Item, 0)
```

when:

```go
var items []Item
```

is sufficient.

Likewise do not create:

```go
make(map[string]string)
```

until the map actually needs writes.

But keep capacity preallocation where profiling/data size makes it useful.

---

# 33. Do not copy slices/maps unnecessarily

Be suspicious of defensive copying with no mutation threat.

Bad:

```go
result := make([]string, len(input))
copy(result, input)
return result
```

unless ownership/mutation semantics require the copy.

Do not add allocations "for safety" without a concrete reason.

---

# 34. Avoid premature performance tricks

Do not introduce:

- `sync.Pool`
- manual buffer reuse
- unsafe conversions
- custom allocators
- elaborate caches
- goroutine pools
- lock-free structures

without evidence that the code needs them.

Simple correct code first.

Performance optimizations should solve measured problems.

---

# 35. Do not add goroutines unnecessarily

Be suspicious of:

```go
go func() {
	...
}()
```

added merely to make something "non-blocking."

Every goroutine introduces:

- lifecycle concerns
- cancellation concerns
- race potential
- error propagation problems
- shutdown complexity

Use concurrency when the operation actually benefits from concurrency.

---

# 36. Avoid channel-based architecture for simple synchronous work

Bad:

```txt
handler
↓
channel
↓
worker
↓
channel
↓
processor
```

for logic that could simply be:

```go
processor.Process(ctx, event)
```

Channels are synchronization primitives, not an architectural requirement.

Do not use them to make normal function calls look concurrent.

---

# 37. Use `context.Context` correctly

Do not:

- create `context.Background()` deep in request processing
- accept `context.Context` where cancellation/deadlines are irrelevant
- nil-check context

Bad:

```go
if ctx == nil {
	ctx = context.Background()
}
```

A context parameter should not be nil.

Pass the caller's context through I/O boundaries.

Typical signature:

```go
func (s *Service) GetProject(ctx context.Context, id string) (*Project, error)
```

Do not create new contexts just to satisfy a function signature.

---

# 38. Avoid wrapping every operation in timeouts

Do not mechanically write:

```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()
```

inside every repository/service function.

Timeout policy should usually live at meaningful boundaries.

Repeated nested arbitrary timeouts are difficult to reason about.

---

# 39. Keep logging simple

Avoid logs that merely narrate every function:

```go
logger.Info("entering CreateProject")
logger.Info("validating project")
logger.Info("calling repository")
logger.Info("repository completed")
logger.Info("leaving CreateProject")
```

Log meaningful events:

- failures
- important state transitions
- operational decisions
- external interactions worth tracing

Do not turn application logs into execution commentary.

---

# 40. Avoid logging and returning the same error at every layer

Bad:

```go
result, err := repo.Get(ctx, id)
if err != nil {
	logger.Error("failed to get project", "error", err)
	return nil, err
}
```

if the caller will also log it.

Prefer logging once at the boundary responsible for handling the failure.

Libraries/services should generally return errors.

Handlers/workers/process supervisors decide when to log.

---

# 41. Remove obvious comments

Delete comments like:

```go
// Check if project exists.
if project == nil {
```

```go
// Return the result.
return result
```

```go
// Convert string to lowercase.
domain = strings.ToLower(domain)
```

Keep comments for:

- business rules
- invariants
- non-obvious decisions
- external system quirks
- workarounds
- concurrency reasoning

Comments should explain why, not narrate syntax.

---

# 42. Avoid over-packaging

Do not create a package for every type/helper.

Bad:

```txt
internal/
  domainparser/
  stringutils/
  validationhelper/
  projectmapper/
  pointerhelper/
  responsebuilder/
```

Prefer packages around actual domains/capabilities.

A package should represent a coherent concept, not one function.

---

# 43. Remove vague utility packages

Audit packages named:

```txt
utils
helpers
common
shared
misc
core
base
```

These often accumulate unrelated abstractions.

Move useful functions to the domain that owns them.

Delete trivial helpers.

Avoid creating another generic utility package during cleanup.

---

# 44. Avoid unnecessary wrapper structs

Bad:

```go
type ProjectID struct {
	Value string
}
```

when a plain string is sufficient.

A custom type may be appropriate:

```go
type ProjectID string
```

if it prevents mixing IDs or adds domain behavior.

But do not wrap primitives in structs without a concrete benefit.

---

# 45. Use custom primitive types selectively

This can be useful:

```go
type ProjectID string
type Region string
```

when it prevents accidental mixing.

But do not produce:

```go
type ProjectName string
type ProjectDescription string
type ProjectImage string
type ProjectStatusString string
```

for every field.

Use domain types where they materially improve correctness.

---

# 46. Do not duplicate standard library functionality

Before keeping a helper, check whether Go already has the operation.

Prefer:

```go
strings.TrimSpace
strings.ToLower
slices.Contains
maps.Clone
errors.Is
errors.As
cmp.Or
strconv.Atoi
```

where appropriate.

Do not maintain custom helpers that poorly reimplement the standard library.

---

# 47. Avoid regex when normal string operations work

Bad:

```go
regexp.MustCompile(`\s+`).ReplaceAllString(...)
```

for simple trimming or known delimiters.

Prefer `strings` functions where sufficient.

Regex should solve regex-shaped problems.

---

# 48. Simplify string formatting

Avoid:

```go
fmt.Sprintf("%d", n)
```

in hot/simple paths when:

```go
strconv.Itoa(n)
```

is clearer.

But do not replace readable formatting merely for micro-performance.

---

# 49. Do not create validators for trusted internal structs

Bad:

```go
func validateProject(project Project) error {
	if project.ID == "" {
		return errors.New("missing project ID")
	}
	...
}
```

called in every internal service.

If `Project` is created from external input, validate when creating/parsing it.

Do not repeatedly validate the same object throughout the system.

---

# 50. Keep boundary validation

Do not blindly remove validation.

Validation is appropriate for:

- HTTP requests
- query/path parameters
- queue messages
- webhooks
- config/env vars
- external APIs
- user input
- decoded untrusted JSON
- persisted schemaless documents

The rule is:

> **Defend against external uncertainty, not against your own correctly typed code.**

---

# 51. Avoid excessive validation libraries

If normal Go code is sufficient:

```go
if req.Domain == "" {
	return ErrDomainRequired
}
```

do not introduce a large validation framework solely to avoid three `if` statements.

Use an existing validation library if the project already relies on it and the schema complexity warrants it.

---

# 52. Keep business rules explicit

Do not hide meaningful rules behind generic abstractions.

Bad:

```go
if validator.IsValid(project) {
```

when the real business rule is:

```go
if project.Status != StatusActive {
	return ErrProjectInactive
}
```

Domain rules should be visible in the code.

---

# 53. Avoid giant config objects passed everywhere

Bad:

```go
func Process(ctx context.Context, cfg Config, options Options, metadata Metadata)
```

when the function needs:

```go
projectID
region
```

Pass the data the function actually needs.

Narrow function signatures improve readability and testability.

---

# 54. Do not introduce unnecessary option structs

Bad:

```go
type GetProjectOptions struct {
	ID string
}
```

for:

```go
GetProject(ctx, GetProjectOptions{ID: id})
```

Prefer:

```go
GetProject(ctx, id)
```

Option structs are useful when several meaningful parameters travel together or optional parameters exist.

---

# 55. Avoid unnecessary return structs

Bad:

```go
type ExistsResult struct {
	Exists bool
}
```

Prefer:

```go
func Exists(...) (bool, error)
```

Use structs when multiple related return values form a meaningful object.

---

# 56. Avoid needless named return values

Bad:

```go
func GetProject(id string) (project *Project, err error) {
	...
}
```

unless named returns materially improve the function.

Prefer:

```go
func GetProject(id string) (*Project, error) {
```

Avoid naked returns in non-trivial functions.

---

# 57. Remove defensive `recover()` usage

Search for:

```go
defer func() {
	if r := recover(); r != nil {
		...
	}
}()
```

Do not use `recover` to turn programming bugs into normal control flow.

Recover only at genuine process/request boundaries where keeping the process alive is intentional.

Do not put `recover()` inside normal business functions.

---

# 58. Avoid `panic` for normal errors

Do not use `panic` for:

- validation failures
- missing DB rows
- network errors
- malformed user input

Return errors.

Panics are appropriate for states that make program initialization or continued execution impossible.

---

# 59. Avoid stateful singleton/global slop

Review:

```go
var defaultClient ...
var globalConfig ...
var singleton ...
```

Globals are fine for true constants/immutable package state.

Do not use mutable package globals as a shortcut for dependency wiring.

Pass dependencies explicitly.

---

# 60. Do not abstract simple database operations unnecessarily

Bad:

```txt
Service
→ Repository
→ Store
→ DAO
→ QueryExecutor
→ sql.DB
```

Use the minimum layering that matches the application.

A repository around SQL/Mongo queries is reasonable.

A repository wrapped by another object that just forwards everything is not.

---

# 61. Keep SQL/query code obvious

Do not create elaborate query builders for three static queries unless dynamic composition is actually needed.

Plain SQL is often easier to understand:

```go
const query = `
	SELECT id, name
	FROM projects
	WHERE id = $1
`
```

Do not hide straightforward SQL behind abstraction solely to avoid writing SQL.

---

# 62. Avoid transactional abstraction slop

Do not invent elaborate:

```go
TransactionManager
UnitOfWork
TransactionProvider
TransactionRunner
```

if this suffices:

```go
tx, err := db.BeginTx(ctx, nil)
if err != nil {
	return err
}

defer tx.Rollback()

...

return tx.Commit()
```

Abstract transaction handling only when repeated complexity justifies it.

---

# 63. Use constants where they clarify meaning

Do not replace every string with a constant.

Good:

```go
const duplicateKeyCode = 11000
```

when the number has domain/driver meaning.

Unnecessary:

```go
const emptyString = ""
const trueValue = true
```

Constants should communicate meaning.

---

# 64. Do not over-enum strings

Custom string constants are useful:

```go
type DeploymentStatus string

const (
	DeploymentPending DeploymentStatus = "pending"
	DeploymentRunning DeploymentStatus = "running"
)
```

But do not create enums for every arbitrary string if there is no closed set of valid values.

---

# 65. Prefer readable switches

Go `switch` is often better than abstraction.

Bad:

```go
handlers := map[string]func(Event) error{
	"insert": handleInsert,
	"delete": handleDelete,
}
```

when a simple switch is clearer:

```go
switch event.Type {
case "insert":
	return handleInsert(event)

case "delete":
	return handleDelete(event)

default:
	return ErrUnsupportedEvent
}
```

Use dispatch maps when dynamic registration is genuinely valuable.

---

# 66. Do not force polymorphism

If there are only two slightly different cases, a switch may be clearer than:

```go
type Strategy interface {
	Execute(...)
}
```

plus:

```go
InsertStrategy
DeleteStrategy
ReplaceStrategy
```

Go does not require every branch to become polymorphism.

---

# 67. Avoid excessive mocks

Do not create interfaces purely so every dependency can be mocked.

Prefer testing real behavior where practical.

Use small interfaces around expensive/external boundaries.

Do not turn every internal type into an interface because "tests need mocks."

---

# 68. Keep tests simple too

Apply the cleanup to tests.

Remove:

- enormous test builders
- generic fixture systems
- helper pyramids
- mocks for pure logic
- repeated `any`
- excessive test abstractions

Prefer explicit table-driven tests where appropriate:

```go
tests := []struct {
	name string
	in   string
	want string
}{
	{"lowercase", "EXAMPLE.COM", "example.com"},
	{"trim", " example.com ", "example.com"},
}
```

Do not make tests harder to understand than the code they test.

---

# 69. Do not blindly remove idiomatic Go error handling

This cleanup must not mistake normal Go code for slop.

This is idiomatic and should remain:

```go
if err != nil {
	return err
}
```

Likewise:

```go
value, ok := m[key]
```

```go
if !ok {
	...
}
```

and:

```go
if project == nil {
	...
}
```

can all be correct.

The question is whether the failure/absence is genuinely possible and meaningful.

Do not remove necessary checks merely to reduce line count.

---

# 70. Optimize for code reduction, not line golf

The desired code should be shorter because unnecessary concepts disappeared.

Not because everything was compressed into unreadable expressions.

Bad cleanup:

```go
if err := func() error { ... }(); err != nil { return fmt.Errorf(...) }
```

Prefer boring readable Go.

---

# 71. Fix the root type instead of adding helpers

Whenever you see:

```go
asString(value)
asObjectID(value)
extractDomain(value)
safeValue(value)
toMap(value)
```

trace where `value` originated.

Ask:

1. Why isn't this value already strongly typed?
2. Is this data external?
3. Can it be decoded into a concrete struct at the boundary?
4. Can downstream functions accept the concrete type?
5. Can this helper then disappear?

Always prefer fixing the source of poor typing.

---

# 72. Look for "AI architecture"

Be particularly suspicious of combinations like:

```txt
interfaces.go
factory.go
builder.go
mapper.go
converter.go
validator.go
utils.go
helpers.go
manager.go
processor.go
service.go
repository.go
```

inside one small feature.

Do not assume all these layers are necessary.

Determine what each one actually does.

Collapse layers that merely forward calls or transform identical structures.

---

# 73. Search patterns to audit

Search the repository for:

```txt
any
interface{}
map[string]any
map[string]interface{}
reflect.
recover(
panic(
fmt.Sprintf
strconv.
errors.New
fmt.Errorf
errors.As
errors.Is
== nil
!= nil
type .* interface
Factory
Builder
Manager
Processor
Helper
Utils
Mapper
Converter
Validator
Options
Params
DTO
Entity
Model
ValueOr
Safe
Normalize
Extract
Resolve
Parse
GetString
AsString
ToString
With
context.Background
context.TODO
sync.Pool
go func
make([]

```

Do not automatically change every match.

Use them as places to inspect for unnecessary complexity.

---

# 74. Apply the "de-slop test" to every change

Before adding or keeping code, ask:

> Does this handle something that can genuinely happen?

If no, delete it.

Ask:

> Is this complexity caused by poor typing upstream?

If yes, fix the upstream type.

Ask:

> Does this interface have more than one meaningful implementation or consumer-driven purpose?

If no, consider using the concrete type.

Ask:

> Does this helper express a real concept?

If no, inline it.

Ask:

> Does this abstraction reduce total complexity?

If no, remove it.

Ask:

> Would plain Go be easier to understand?

If yes, use plain Go.

---

# 75. Desired style

Prefer code like:

```go
func (s *Service) MapDomain(ctx context.Context, event DomainMapEvent) error {
	domain := strings.ToLower(strings.TrimSpace(event.Domain))

	return s.domains.Map(ctx, event.ProjectID, domain)
}
```

over:

```go
func (s *Service) MapDomain(ctx context.Context, raw any) error {
	event, err := convertToDomainMapEvent(raw)
	if err != nil {
		return fmt.Errorf("failed converting domain event: %w", err)
	}

	projectID := safeString(event.ProjectID)
	if projectID == "" {
		return nil
	}

	domain := normalizeStringValue(event.Domain)
	if domain == "" {
		return nil
	}

	return s.domainManager.ProcessDomainMapping(
		ctx,
		NewDomainMappingParams(projectID, domain),
	)
}
```

---

# 76. Refactoring process

Work feature-by-feature.

For each feature:

### Step 1
Identify where data enters the system.

Examples:

- HTTP
- queue
- Kafka/NATS/RabbitMQ
- MongoDB
- PostgreSQL
- Redis
- webhook
- external API
- environment/config

### Step 2
Give the input a concrete type.

### Step 3
Validate/decode once.

### Step 4
Follow the data through the application.

Remove unnecessary:

- `any`
- type assertions
- generic maps
- nil guards
- converters
- extractors
- wrapper structs
- interfaces
- pass-through methods
- duplicate DTOs
- generic helpers

### Step 5
Collapse forwarding layers.

### Step 6
Delete dead abstractions.

### Step 7
Run tests and static analysis.

Use the project's normal commands, including where applicable:

```bash
go test ./...
go vet ./...
staticcheck ./...
```

Run formatters after changes:

```bash
gofmt
```

Do not change behavior merely to satisfy style preferences.

---

# 77. Preserve things that are genuinely idiomatic

Do not remove:

- useful interfaces
- meaningful error wrapping
- legitimate nil handling
- boundary validation
- context propagation
- proper resource cleanup
- `defer rows.Close()`
- `defer resp.Body.Close()`
- transaction rollback safety
- mutexes protecting real shared state
- channel synchronization that is actually needed
- driver-specific error handling
- correct integer/error checks
- security-related checks

This is a complexity cleanup, not reckless deletion.

---

# 78. Final desired result

The codebase should end up with:

- more concrete structs
- fewer `any` values
- fewer generic maps
- fewer type assertions
- fewer conversion helpers
- fewer tiny wrapper functions
- fewer pointless interfaces
- fewer forwarding layers
- fewer factories/builders/managers
- less reflection
- less defensive nil handling
- less silent fallback behavior
- simpler error handling
- fewer redundant DTOs
- more direct function calls
- narrower function signatures
- explicit business logic
- validation concentrated at boundaries
- straightforward idiomatic Go

The important metric is not the number of files changed.

The important metric is:

> **Can an engineer trace the behavior without jumping through unnecessary abstractions?**

---

# 79. Most important rule

Do not replace one kind of slop with another.

Do not turn:

```go
value := data["domain"].(string)
```

into:

```go
value, ok := data["domain"]
if !ok {
	return ""
}

domain, ok := value.(string)
if !ok {
	return ""
}
```

and call that a cleanup.

The correct solution is usually:

```go
type Event struct {
	Domain string `json:"domain"`
}
```

followed by:

```go
event.Domain
```

Likewise, do not replace a simple direct call with:

```txt
interface
→ implementation
→ manager
→ helper
→ converter
→ validator
→ actual function
```

The overriding principle is:

> **Make untrusted input safe at the edge. Keep trusted Go code boring everywhere else.**