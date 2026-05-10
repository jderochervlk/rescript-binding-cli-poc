/** Small view model for rendering release choices without leaking file names. */

type compatibility = option<bool>

type input = {
  author: string,
  packageRange: string,
  rescriptRange: string,
  isPackageCompatible: compatibility,
  isRescriptCompatible: compatibility,
}

type row = {
  author: string,
  packageText: string,
  rescriptText: string,
}

let packageLabel = compatibility =>
  switch compatibility {
  | Some(true) => "matches installed"
  | Some(false) => "does not match installed"
  | None => "installed version unknown"
  }

let rescriptLabel = compatibility =>
  switch compatibility {
  | Some(true) => "matches project"
  | Some(false) => "does not match project"
  | None => "project version unknown"
  }

let row = (input: input): row => {
  author: input.author,
  packageText: input.packageRange ++ " - " ++ packageLabel(input.isPackageCompatible),
  rescriptText: input.rescriptRange ++ " - " ++ rescriptLabel(input.isRescriptCompatible),
}
