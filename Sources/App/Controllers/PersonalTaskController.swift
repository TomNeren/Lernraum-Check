import Vapor
import Fluent

struct PersonalTaskController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let personal = routes.grouped("api", "personal")

        personal.post("assign", use: assignTask)
        personal.get(":playerID", use: getOpenTasks)
        personal.post(":taskID", "complete", use: completeTask)
        personal.get(":playerID", "all", use: getAllTasks)
    }

    // POST /api/personal/assign
    @Sendable
    func assignTask(req: Request) async throws -> PersonalTask {
        let input = try req.content.decode(AssignTaskRequest.self)

        let task = PersonalTask(
            playerID: input.playerID,
            title: input.title,
            type: input.type,
            config: input.config,
            dueDate: input.dueDate,
            note: input.note
        )
        try await task.save(on: req.db)
        return task
    }

    // GET /api/personal/:playerID
    @Sendable
    func getOpenTasks(req: Request) async throws -> [PersonalTaskResponse] {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        let tasks = try await PersonalTask.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .filter(\.$completed == false)
            .sort(\.$assignedAt, .descending)
            .all()

        return tasks.map { task in
            PersonalTaskResponse(
                id: task.id!,
                title: task.title,
                type: task.type,
                config: task.config,
                assignedAt: task.assignedAt,
                dueDate: task.dueDate,
                note: task.note,
                completed: task.completed
            )
        }
    }

    // POST /api/personal/:taskID/complete
    @Sendable
    func completeTask(req: Request) async throws -> HTTPStatus {
        guard let taskID: UUID = req.parameters.get("taskID") else {
            throw Abort(.badRequest)
        }

        guard let task = try await PersonalTask.find(taskID, on: req.db) else {
            throw Abort(.notFound, reason: "Aufgabe nicht gefunden.")
        }

        task.completed = true
        task.completedAt = Date()
        try await task.save(on: req.db)
        return .ok
    }

    // GET /api/personal/:playerID/all
    @Sendable
    func getAllTasks(req: Request) async throws -> [PersonalTaskResponse] {
        guard let playerID: UUID = req.parameters.get("playerID") else {
            throw Abort(.badRequest)
        }

        let tasks = try await PersonalTask.query(on: req.db)
            .filter(\.$player.$id == playerID)
            .sort(\.$assignedAt, .descending)
            .all()

        return tasks.map { task in
            PersonalTaskResponse(
                id: task.id!,
                title: task.title,
                type: task.type,
                config: task.config,
                assignedAt: task.assignedAt,
                dueDate: task.dueDate,
                note: task.note,
                completed: task.completed
            )
        }
    }
}
