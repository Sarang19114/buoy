ExUnit.start()

Mix.Task.run("ecto.create", ["--quiet"])
Mix.Task.run("ecto.migrate", ["--quiet"])

Ecto.Adapters.SQL.Sandbox.mode(BuoyMap.Repo, :manual)
