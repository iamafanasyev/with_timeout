defmodule WithTimeout do
  @moduledoc """
  Both total and time limited evaluation of expressions
  """

  @typedoc "Any anonymous function without arguments"
  @type lazy_expression(a) :: (() -> a)

  @typedoc "Evaluation time limit in milliseconds"
  @type evaluation_timeout_in_milliseconds() :: pos_integer()

  @typedoc "`Task.shutdown/2` shutdown timeout backing evaluation"
  @type evaluation_shutdown_timeout_in_milliseconds() :: :brutal_kill | timeout()

  @type evaluation_options() ::
          [
            within_milliseconds: evaluation_timeout_in_milliseconds(),
            with_evaluation_shutdown_timeout_in_milliseconds:
              evaluation_shutdown_timeout_in_milliseconds()
          ]

  @typedoc "Evaluation result payload in case of exception during the evaluation"
  @type evaluation_exception() :: {:exception, Exception.t(), Exception.stacktrace()}

  @typedoc "Evaluation result payload in case of backing task termination"
  @type evaluation_termination(a) :: {:exit, reason :: a}

  @typedoc "Evaluation result payload in case of evaluation timeout"
  @type evaluation_timeout() :: :timeout

  @typedoc "Evaluation result payload"
  @type evaluation_error() ::
          evaluation_exception()
          | evaluation_termination(term())
          | evaluation_timeout()

  @doc """
  Evaluates "lazy expression" (anonymous function without arguments)
  within the passed time interval.

  The main difference from basic `Task` facility is that the evaluation is ***total***,
  so you get the result even if the expression raises.
  The expression evaluation task instead of being linked to the caller
  is supervised by `Task.Supervisor` spawned under the hood each time you call the function
  and linked to the caller process.

  Thus, you get "supervised" expression evaluation:
   * caller process shutdown ***causes*** expression evaluation task to shut down
     (same as `Task.async/1`, but what's missing in `Task.Supervisor.async_nolink/3` in general);
   * expression evaluation task shutdown ***does not*** cause the caller process to shut down.

  If the expression does not terminate within the passed time interval,
  its evaluation will be terminated, so keep this in mind, if it has side effects
  (effectful expression evaluation is not reproducible in general).

  Optional evaluation shutdown timeout backs underlying `Task.shutdown/2`,
  so all acquired by `lazy_expression` resources (e.g. linked processes)
  can be gracefully terminated or released. Its default value is `5000ms`.
  """
  @spec evaluate(lazy_expression(any()), evaluation_options()) ::
          {:error, evaluation_error()}
          | {:ok, evaluated_expression :: any()}
  def evaluate(lazy_expression, evaluation_options)

  def evaluate(
        lazy_expression,
        within_milliseconds: within_milliseconds
      ) do
    lazy_expression
    |> evaluate(
      within_milliseconds: within_milliseconds,
      with_evaluation_shutdown_timeout_in_milliseconds: 5000
    )
  end

  def evaluate(
        lazy_expression,
        within_milliseconds: within_milliseconds,
        with_evaluation_shutdown_timeout_in_milliseconds:
          with_evaluation_shutdown_timeout_in_milliseconds
      ) do
    [evaluation_result] =
      Stream.resource(
        fn ->
          {:ok, acquired_local_task_supervisor_pid} = Task.Supervisor.start_link()

          [evaluate_expression_using: acquired_local_task_supervisor_pid]
        end,
        fn
          [evaluate_expression_using: acquired_local_task_supervisor_pid]
          when is_pid(acquired_local_task_supervisor_pid) ->
            supervised_by_local_task_supervisor_task =
              Task.Supervisor.async_nolink(
                acquired_local_task_supervisor_pid,
                lazy_expression,
                # evaluate/3 caller shutdown -> local task supervisor shutdown -> lazy expression evaluation shutdown
                shutdown: with_evaluation_shutdown_timeout_in_milliseconds
              )

            {
              [
                case Task.yield(supervised_by_local_task_supervisor_task, within_milliseconds) ||
                       Task.shutdown(
                         supervised_by_local_task_supervisor_task,
                         with_evaluation_shutdown_timeout_in_milliseconds
                       ) do
                  {:ok, evaluated_expression} ->
                    {:ok, evaluated_expression}

                  nil ->
                    {:error, :timeout}

                  {:exit, {exception, stacktrace}}
                  when is_exception(exception) and is_list(stacktrace) ->
                    {:error, {:exception, exception, stacktrace}}

                  {:exit, reason} ->
                    {:error, {:exit, reason}}
                end
              ],
              [shutdown: acquired_local_task_supervisor_pid]
            }

          [shutdown: acquired_local_task_supervisor_pid]
          when is_pid(acquired_local_task_supervisor_pid) ->
            {:halt, [shutdown: acquired_local_task_supervisor_pid]}
        end,
        fn [shutdown: acquired_local_task_supervisor_pid]
           when is_pid(acquired_local_task_supervisor_pid) ->
          Process.exit(acquired_local_task_supervisor_pid, :normal)
        end
      )
      |> Enum.to_list()

    evaluation_result
  end
end
