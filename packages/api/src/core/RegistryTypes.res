type fileEntry = {
  relativePath: string,
  content: string,
}

type normalizedFileEntry = {
  relativePath: string,
  content: string,
  bytes: int,
}

type release = {
  id: string,
  packageName: string,
  variantLabel: string,
  variantSlug: string,
  publisherLogin: string,
  peerPackageRange: string,
  rescriptRange: string,
  description: option<string>,
  createdAt: string,
}

type releaseWithCompatibility = {
  release: release,
  isPackageCompatible: option<bool>,
  isRescriptCompatible: option<bool>,
  compatibilityRank: int,
}

type publishInput = {
  packageName: string,
  variantLabel: string,
  peerPackageRange: string,
  rescriptRange: string,
  description: option<string>,
  files: array<fileEntry>,
}
