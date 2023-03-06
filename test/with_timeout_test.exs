defmodule WithTimeoutTest do
  use ExUnit.Case, async: true

  describe "WithTimeout.evaluate/2" do
    test "should successfully evaluate non-divergent expression whose evaluation fits the passed time interval" do
      assert fn ->
               Process.sleep(30)
               42
             end
             |> WithTimeout.evaluate(within_milliseconds: 50) ===
               {:ok, 42}
    end

    test "should terminate expression evaluation that does not fit the passed time interval" do
      assert fn ->
               Process.sleep(50)
               assert false, "expected to be terminated by timeout"
             end
             |> WithTimeout.evaluate(within_milliseconds: 30) ===
               {:error, :timeout}

      # To be sure the evaluation has been terminated
      Process.sleep(30)
    end

    test "should be able to evaluate divergent expression" do
      assert match?(
               {:error, {:exception, %RuntimeError{message: "42"}, _stacktrace}},
               fn -> raise "42" end
               |> WithTimeout.evaluate(within_milliseconds: 100)
             )
    end

    test "should be able to evaluate expression whose process was killed" do
      infinite_loop =
        spawn(fn ->
          receive do
          end
        end)

      assert fn ->
               Process.link(infinite_loop)
               Process.exit(infinite_loop, {:some, :fancy, :reason, :to, :shut, :down})
               Process.sleep(100)
               assert false, "expected to be killed by linked process"
             end
             |> WithTimeout.evaluate(within_milliseconds: 200) ===
               {:error, {:exit, {:some, :fancy, :reason, :to, :shut, :down}}}
    end

    test "should be able to avoid resource leakage using proper evaluation shutdown timeout configuration" do
      assert fn ->
               Process.flag(:trap_exit, true)

               receive do
                 # Pretending there is a long running resource release
               end
             end
             |> WithTimeout.evaluate(
               within_milliseconds: 10,
               with_evaluation_shutdown_timeout_in_milliseconds: 20
             ) ===
               {:error, {:exit, :killed}}

      assert WithTimeout.evaluate(
               fn ->
                 Process.flag(:trap_exit, true)

                 receive do
                   {:EXIT, _from, _reason} ->
                     # Acquired resources release simulation
                     Process.sleep(10)
                     # Resources released, return the result
                     42
                 end
               end,
               within_milliseconds: 50,
               with_evaluation_shutdown_timeout_in_milliseconds: 20
             ) ===
               {:ok, 42}
    end
  end
end
