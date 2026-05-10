/** Reads dependency metadata from a parsed package.json object.

    The CLI keeps JSON parsing in Node, then asks this module for the small
    project facts the add and publish flows need. */

type dependencies
type packageJson

@get external peerDependencies: packageJson => option<dependencies> = "peerDependencies"
@get external dependencies: packageJson => option<dependencies> = "dependencies"
@get external devDependencies: packageJson => option<dependencies> = "devDependencies"
@get_index external dependencyValue: (dependencies, string) => option<string> = ""
@scope("Object") @val external keys: dependencies => array<string> = "keys"
@send external trim: string => string = "trim"
@send external localeCompare: (string, string) => int = "localeCompare"
@send external push: (array<'a>, 'a) => int = "push"
@send external sortWith: (array<string>, (string, string) => int) => array<string> = "sort"

let dependencyGroups = packageJson => {
  let groups: array<dependencies> = []

  [peerDependencies(packageJson), dependencies(packageJson), devDependencies(packageJson)]
  ->Array.forEach(group => {
    switch group {
    | Some(group) => push(groups, group)->ignore
    | None => ()
    }
  })

  groups
}

let dependencyVersionFrom = (packageJson, dependencyName) => {
  let found: ref<option<string>> = ref(None)

  packageJson
  ->dependencyGroups
  ->Array.forEach(group => {
    switch found.contents {
    | Some(_) => ()
    | None =>
      switch dependencyValue(group, dependencyName) {
      | Some(version) =>
        if version->trim != "" {
          found := Some(version)
        }
      | None => ()
      }
    }
  })

  found.contents
}

let dependencyNamesFrom = packageJson => {
  let names: array<string> = []

  packageJson
  ->dependencyGroups
  ->Array.forEach(group => {
    group
    ->keys
    ->Array.forEach(name => {
      if name != "rescript" && !(names->Array.some(existing => existing == name)) {
        push(names, name)->ignore
      }
    })
  })

  names->sortWith((left, right) => left->localeCompare(right))
}
