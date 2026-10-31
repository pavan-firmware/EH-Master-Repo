/**
 * EH Home Desktop — Engineering Source Control & Repositories Workspace
 * (Parts 14–21)
 *
 * Professional Git & Source Workspace providing:
 * - Canonical master remote repository view (pavan-firmware/EH-Master-Repo)
 * - Real local working copy status, branch, commit history, and dirty/clean state
 * - Real repository directory and file tree navigation
 * - Multi-language source code viewer (C, C++, TS, JS, Dart, Rust, JSON, SQL, YAML, Markdown)
 * - Dynamic permission boundary (NOT_CONNECTED, READ_ONLY, WRITE_ACCESS)
 * - Zero fake commits, zero fake pushes, zero fake GitHub actions
 */

import React, { useState, useEffect, useCallback } from 'react';
import {
  GitBranch,
  Folder,
  FileCode,
  FileText,
  FileJson,
  ExternalLink,
  Copy,
  Check,
  RefreshCw,
  FolderOpen,
  ArrowLeft,
  Lock,
  Unlock,
  Code,
  Terminal,
  Key,
  ShieldCheck,
  AlertCircle,
  FileDiff,
  UploadCloud,
  GitPullRequest,
} from 'lucide-react';
import {
  repositoryService,
  RepositoryWorkspaceInfo,
  RepositoryFileItem,
  SourceFileContentResponse,
  GitHubAuthStatus,
  GitHubRemoteRepoDetails,
} from '../../services/repository.service';
import { logger } from '../../lib/logger';

export const RepositoriesView: React.FC = () => {
  const [workspaceInfo, setWorkspaceInfo] = useState<RepositoryWorkspaceInfo | null>(null);
  const [remoteDetails, setRemoteDetails] = useState<GitHubRemoteRepoDetails | null>(null);
  const [authStatus, setAuthStatus] = useState<GitHubAuthStatus | null>(null);
  const [currentSubpath, setCurrentSubpath] = useState<string>('');
  const [fileList, setFileList] = useState<RepositoryFileItem[]>([]);
  const [selectedFile, setSelectedFile] = useState<SourceFileContentResponse | null>(null);
  const [isLoadingFiles, setIsLoadingFiles] = useState<boolean>(false);
  const [isLoadingContent, setIsLoadingContent] = useState<boolean>(false);
  const [isRefreshing, setIsRefreshing] = useState<boolean>(false);
  const [copiedUrl, setCopiedUrl] = useState<boolean>(false);
  const [copiedContent, setCopiedContent] = useState<boolean>(false);

  // Auth Modal State
  const [showAuthModal, setShowAuthModal] = useState<boolean>(false);
  const [tokenInput, setTokenInput] = useState<string>('');
  const [writeAccessCheckbox, setWriteAccessCheckbox] = useState<boolean>(false);
  const [authError, setAuthError] = useState<string | null>(null);
  const [showChangedFiles, setShowChangedFiles] = useState<boolean>(false);

  const loadRepositoryData = useCallback(async () => {
    setIsRefreshing(true);
    try {
      const [ws, remote, auth] = await Promise.all([
        repositoryService.getWorkspaceInfo(),
        repositoryService.fetchRemoteRepoDetails(),
        repositoryService.getGitHubAuthStatus(),
      ]);
      setWorkspaceInfo(ws);
      setRemoteDetails(remote);
      setAuthStatus(auth);
    } catch (err) {
      logger.error('Failed to load repository workspace data', err);
    } finally {
      setIsRefreshing(false);
    }
  }, []);

  const loadDirectory = useCallback(async (subpath: string) => {
    setIsLoadingFiles(true);
    try {
      const items = await repositoryService.listFiles(subpath);
      setFileList(items);
      setCurrentSubpath(subpath);
    } catch (err) {
      logger.error('Failed to list files in directory', err);
    } finally {
      setIsLoadingFiles(false);
    }
  }, []);

  useEffect(() => {
    loadRepositoryData();
    loadDirectory('');
  }, [loadRepositoryData, loadDirectory]);

  const handleSelectFile = async (item: RepositoryFileItem) => {
    if (item.isDir) {
      loadDirectory(item.path);
    } else {
      setIsLoadingContent(true);
      try {
        const content = await repositoryService.readSourceFile(item.path);
        setSelectedFile(content);
      } catch (err) {
        logger.error('Failed to read source file', err);
      } finally {
        setIsLoadingContent(false);
      }
    }
  };

  const handleNavigateUp = () => {
    if (!currentSubpath) return;
    const parts = currentSubpath.split('/');
    parts.pop();
    const parent = parts.join('/');
    loadDirectory(parent);
  };

  const copyCloneUrl = () => {
    if (workspaceInfo?.canonicalRemoteUrl) {
      navigator.clipboard.writeText(workspaceInfo.canonicalRemoteUrl + '.git');
      setCopiedUrl(true);
      setTimeout(() => setCopiedUrl(false), 2000);
    }
  };

  const copyFileContent = () => {
    if (selectedFile?.content) {
      navigator.clipboard.writeText(selectedFile.content);
      setCopiedContent(true);
      setTimeout(() => setCopiedContent(false), 2000);
    }
  };

  const handleSaveAuthToken = async () => {
    if (!tokenInput.trim()) {
      setAuthError('Token cannot be empty');
      return;
    }
    setAuthError(null);
    try {
      const updated = await repositoryService.setGitHubToken(tokenInput.trim(), writeAccessCheckbox);
      setAuthStatus(updated);
      setShowAuthModal(false);
      setTokenInput('');
    } catch (err: any) {
      setAuthError(err.message || 'Failed to authenticate GitHub credentials');
    }
  };

  const handleClearAuthToken = async () => {
    try {
      const updated = await repositoryService.clearGitHubToken();
      setAuthStatus(updated);
      setShowAuthModal(false);
      setTokenInput('');
    } catch (err: any) {
      setAuthError(err.message || 'Failed to disconnect token');
    }
  };

  const getFileIcon = (isDir: boolean, ext?: string) => {
    if (isDir) return <Folder className="h-4 w-4 text-[#E8AB53] shrink-0" />;
    switch (ext) {
      case 'ts':
      case 'tsx':
      case 'js':
      case 'jsx':
      case 'dart':
      case 'c':
      case 'cpp':
      case 'h':
      case 'rs':
      case 'py':
        return <FileCode className="h-4 w-4 text-[#569CD6] shrink-0" />;
      case 'json':
      case 'yaml':
      case 'yml':
      case 'toml':
        return <FileJson className="h-4 w-4 text-[#CCA700] shrink-0" />;
      default:
        return <FileText className="h-4 w-4 text-[#9D9D9D] shrink-0" />;
    }
  };

  const breadcrumbParts = currentSubpath ? currentSubpath.split('/') : [];

  return (
    <div className="space-y-3.5 max-w-7xl mx-auto font-sans text-[13px]">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 border-b border-[#3C3C3C] pb-3">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-xs font-mono text-[#858585]">workbench &gt; source control &gt;</span>
            <h1 className="text-base font-semibold text-white uppercase tracking-wide">EH-Master-Repo</h1>
            <span className="rounded bg-[#007ACC]/10 px-2 py-0.5 text-[11px] font-mono text-[#007ACC] border border-[#007ACC]/30 font-medium">
              pavan-firmware/EH-Master-Repo
            </span>
          </div>
          <p className="text-xs text-[#858585] mt-1">
            Authoritative Master Repository Workspace: Remote Git status, real local working tree, and multi-language source viewer.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowAuthModal(true)}
            className="flex items-center gap-1.5 rounded bg-[#252526] border border-[#3C3C3C] px-3 py-1.5 text-xs font-medium text-[#CCCCCC] hover:bg-[#2D2D2D] transition"
          >
            <Key className="h-3.5 w-3.5 text-[#007ACC]" />
            <span>GitHub Auth</span>
          </button>

          <button
            onClick={copyCloneUrl}
            className="flex items-center gap-1.5 rounded bg-[#252526] border border-[#3C3C3C] px-3 py-1.5 text-xs font-medium text-[#CCCCCC] hover:bg-[#2D2D2D] transition"
            title="Copy Git Clone URL"
          >
            {copiedUrl ? <Check className="h-3.5 w-3.5 text-[#4EC9B0]" /> : <Copy className="h-3.5 w-3.5" />}
            <span>{copiedUrl ? 'Copied Clone URL' : 'Copy Clone URL'}</span>
          </button>

          <a
            href={workspaceInfo?.canonicalRemoteUrl || 'https://github.com/pavan-firmware/EH-Master-Repo'}
            target="_blank"
            rel="noreferrer"
            className="flex items-center gap-1.5 rounded bg-[#0E639C] hover:bg-[#1177BB] px-3 py-1.5 text-xs font-medium text-white transition"
          >
            <ExternalLink className="h-3.5 w-3.5" />
            <span>Open in GitHub</span>
          </a>

          <button
            onClick={loadRepositoryData}
            disabled={isRefreshing}
            className="flex items-center gap-1.5 rounded bg-[#252526] border border-[#3C3C3C] px-2.5 py-1.5 text-xs font-medium text-[#CCCCCC] hover:bg-[#2D2D2D] transition"
            title="Refresh Repository State"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${isRefreshing ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {/* Summary Cards: Remote vs Local State */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {/* Remote Repository Card */}
        <div className="rounded border border-[#3C3C3C] bg-[#252526] p-3.5 space-y-2.5">
          <div className="flex items-center justify-between border-b border-[#333333] pb-2">
            <div className="flex items-center gap-2 text-xs font-semibold text-white">
              <GitBranch className="h-4 w-4 text-[#007ACC]" />
              <span>REMOTE REPOSITORY (GitHub)</span>
            </div>
            <span className={`rounded px-2 py-0.5 text-[11px] font-mono border font-medium ${
              authStatus?.authState === 'WRITE_ACCESS'
                ? 'bg-[#4EC9B0]/10 border-[#4EC9B0]/30 text-[#4EC9B0]'
                : authStatus?.authState === 'READ_ONLY'
                ? 'bg-[#007ACC]/10 border-[#007ACC]/30 text-[#007ACC]'
                : 'bg-[#333333] border-[#444444] text-[#9D9D9D]'
            }`}>
              {authStatus?.authState === 'WRITE_ACCESS'
                ? 'Authenticated (Write Access)'
                : authStatus?.authState === 'READ_ONLY'
                ? 'Authenticated (Read-Only)'
                : 'Not Connected (Public Read-Only)'}
            </span>
          </div>

          <div className="grid grid-cols-2 gap-2 text-xs font-mono">
            <div>
              <span className="text-[#858585] text-[11px]">Repository:</span>
              <div className="text-white font-medium">{workspaceInfo?.owner}/{workspaceInfo?.repoName}</div>
            </div>
            <div>
              <span className="text-[#858585] text-[11px]">Default Branch:</span>
              <div className="text-[#4EC9B0]">{workspaceInfo?.defaultBranch || 'main'}</div>
            </div>
            <div>
              <span className="text-[#858585] text-[11px]">Visibility:</span>
              <div className="text-[#CCCCCC]">{remoteDetails?.isPrivate ? 'Private' : 'Public'}</div>
            </div>
            <div>
              <span className="text-[#858585] text-[11px]">Write Permissions:</span>
              <div className="flex items-center gap-1">
                {authStatus?.canPush ? (
                  <span className="text-[#4EC9B0] flex items-center gap-1">
                    <Unlock className="h-3 w-3" />
                    <span>Enabled</span>
                  </span>
                ) : (
                  <span className="text-amber-400 flex items-center gap-1">
                    <Lock className="h-3 w-3" />
                    <span>Read-Only (No Write Access)</span>
                  </span>
                )}
              </div>
            </div>
          </div>

          {/* Action Row for Git Write Gating */}
          <div className="pt-2 border-t border-[#333333] flex items-center gap-2">
            <button
              disabled={!authStatus?.canPush}
              title={authStatus?.canPush ? 'Push changes to GitHub' : 'Permission Gated: Write token required'}
              className="flex items-center gap-1.5 rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1 text-xs font-mono text-[#CCCCCC] hover:bg-[#2D2D2D] disabled:opacity-40 disabled:pointer-events-none transition"
            >
              <UploadCloud className="h-3.5 w-3.5 text-[#007ACC]" />
              <span>Push Changes</span>
            </button>
            <button
              disabled={!authStatus?.canCreatePr}
              title={authStatus?.canCreatePr ? 'Create pull request on GitHub' : 'Permission Gated: Write token required'}
              className="flex items-center gap-1.5 rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1 text-xs font-mono text-[#CCCCCC] hover:bg-[#2D2D2D] disabled:opacity-40 disabled:pointer-events-none transition"
            >
              <GitPullRequest className="h-3.5 w-3.5 text-[#4EC9B0]" />
              <span>Create PR</span>
            </button>
            {!authStatus?.canPush && (
              <span className="text-[10.5px] font-mono text-[#858585] italic">
                (Write actions safely disabled in Read-Only mode)
              </span>
            )}
          </div>
        </div>

        {/* Local Workspace Card */}
        <div className="rounded border border-[#3C3C3C] bg-[#252526] p-3.5 space-y-2.5">
          <div className="flex items-center justify-between border-b border-[#333333] pb-2">
            <div className="flex items-center gap-2 text-xs font-semibold text-white">
              <FolderOpen className="h-4 w-4 text-[#E8AB53]" />
              <span>LOCAL WORKSPACE</span>
            </div>
            <button
              onClick={() => setShowChangedFiles(!showChangedFiles)}
              className={`rounded px-2 py-0.5 text-[11px] font-mono font-medium transition ${
                workspaceInfo?.isClean
                  ? 'bg-[#4EC9B0]/10 text-[#4EC9B0] border border-[#4EC9B0]/30'
                  : 'bg-amber-500/10 text-amber-400 border border-amber-500/30 hover:bg-amber-500/20'
              }`}
            >
              {workspaceInfo?.isClean
                ? 'Working tree clean'
                : `${workspaceInfo?.changedFilesCount || 0} modified files (click to inspect)`}
            </button>
          </div>

          <div className="space-y-1 text-xs font-mono">
            <div className="truncate">
              <span className="text-[#858585] text-[11px]">Local Path: </span>
              <span className="text-[#CCCCCC]">{workspaceInfo?.localWorkspacePath}</span>
            </div>
            <div className="flex items-center justify-between">
              <div>
                <span className="text-[#858585] text-[11px]">Branch: </span>
                <span className="text-white font-medium">{workspaceInfo?.currentBranch}</span>
              </div>
              <div>
                <span className="text-[#858585] text-[11px]">Latest Commit: </span>
                <span className="text-[#569CD6]">{workspaceInfo?.lastCommitSha?.slice(0, 8) || 'N/A'}</span>
              </div>
            </div>
            {workspaceInfo?.lastCommitMessage && (
              <div className="truncate text-[#9D9D9D] text-[11.5px]">
                &quot;{workspaceInfo.lastCommitMessage}&quot;
              </div>
            )}
          </div>

          {/* Collapsible Changed Files List */}
          {showChangedFiles && workspaceInfo?.changedFiles && workspaceInfo.changedFiles.length > 0 && (
            <div className="mt-2 p-2 bg-[#1E1E1E] rounded border border-[#333333] space-y-1 text-xs font-mono max-h-32 overflow-y-auto">
              <div className="text-[11px] text-[#858585] font-semibold flex items-center gap-1 pb-1 border-b border-[#2D2D2D]">
                <FileDiff className="h-3 w-3 text-amber-400" />
                <span>Modified Files:</span>
              </div>
              {workspaceInfo.changedFiles.map((f, i) => (
                <div key={i} className="text-[#CCCCCC] text-[11px] truncate">
                  {f}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Main Engineering Workbench: File Explorer + Source Viewer */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-3 min-h-[500px]">
        {/* Left Column: Real Repository Structure Explorer */}
        <div className="lg:col-span-4 rounded border border-[#3C3C3C] bg-[#252526] flex flex-col overflow-hidden">
          {/* Explorer Header */}
          <div className="p-3 border-b border-[#333333] bg-[#1E1E1E] flex items-center justify-between">
            <div className="flex items-center gap-1.5 text-xs font-semibold text-white">
              <Code className="h-4 w-4 text-[#007ACC]" />
              <span>Repository Files</span>
            </div>
            {currentSubpath && (
              <button
                onClick={handleNavigateUp}
                className="flex items-center gap-1 text-[11px] font-mono text-[#007ACC] hover:text-[#569CD6] transition"
              >
                <ArrowLeft className="h-3 w-3" />
                <span>Up one level</span>
              </button>
            )}
          </div>

          {/* Breadcrumb Path Bar */}
          <div className="px-3 py-1.5 bg-[#181818] border-b border-[#2D2D2D] text-[11px] font-mono text-[#858585] flex items-center gap-1 overflow-x-auto">
            <button
              onClick={() => loadDirectory('')}
              className="text-[#007ACC] hover:underline hover:text-[#569CD6]"
            >
              root
            </button>
            {breadcrumbParts.map((part, idx) => {
              const sub = breadcrumbParts.slice(0, idx + 1).join('/');
              return (
                <React.Fragment key={idx}>
                  <span className="text-[#555555]">/</span>
                  <button
                    onClick={() => loadDirectory(sub)}
                    className="text-[#007ACC] hover:underline hover:text-[#569CD6] truncate"
                  >
                    {part}
                  </button>
                </React.Fragment>
              );
            })}
          </div>

          {/* File & Directory List */}
          <div className="flex-1 overflow-y-auto p-1.5 space-y-0.5">
            {isLoadingFiles ? (
              <div className="p-4 text-center text-xs text-[#858585] italic font-mono">
                Scanning workspace files...
              </div>
            ) : fileList.length === 0 ? (
              <div className="p-4 text-center text-xs text-[#858585] italic font-mono">
                Empty directory
              </div>
            ) : (
              fileList.map((item) => (
                <button
                  key={item.path}
                  onClick={() => handleSelectFile(item)}
                  className={`w-full flex items-center justify-between px-2.5 py-1.5 rounded text-xs transition font-mono ${
                    selectedFile?.filePath === item.path
                      ? 'bg-[#37373D] text-white font-medium border-l-2 border-[#007ACC]'
                      : 'text-[#CCCCCC] hover:bg-[#2A2D2E] hover:text-white'
                  }`}
                >
                  <div className="flex items-center gap-2 truncate">
                    {getFileIcon(item.isDir, item.extension)}
                    <span className="truncate">{item.name}</span>
                  </div>
                  {!item.isDir && item.sizeBytes > 0 && (
                    <span className="text-[10px] text-[#777777]">
                      {item.sizeBytes > 1024 ? `${(item.sizeBytes / 1024).toFixed(1)} KB` : `${item.sizeBytes} B`}
                    </span>
                  )}
                </button>
              ))
            )}
          </div>
        </div>

        {/* Right Column: Source Code Viewer & Inspector */}
        <div className="lg:col-span-8 rounded border border-[#3C3C3C] bg-[#252526] flex flex-col overflow-hidden">
          {/* Source Viewer Header */}
          <div className="p-3 border-b border-[#333333] bg-[#1E1E1E] flex items-center justify-between">
            <div className="flex items-center gap-2 truncate">
              <FileCode className="h-4 w-4 text-[#4EC9B0]" />
              <span className="text-xs font-semibold text-white font-mono truncate">
                {selectedFile ? selectedFile.filePath : 'No file selected'}
              </span>
              {selectedFile && (
                <span className="rounded bg-[#333333] px-2 py-0.5 text-[10px] font-mono text-[#CCCCCC] uppercase">
                  {selectedFile.language}
                </span>
              )}
            </div>

            {selectedFile && (
              <div className="flex items-center gap-2">
                <button
                  onClick={copyFileContent}
                  className="flex items-center gap-1 rounded bg-[#2D2D2D] hover:bg-[#383838] border border-[#3C3C3C] px-2.5 py-1 text-xs text-[#CCCCCC] transition"
                  title="Copy File Content"
                >
                  {copiedContent ? <Check className="h-3 w-3 text-[#4EC9B0]" /> : <Copy className="h-3 w-3" />}
                  <span>{copiedContent ? 'Copied' : 'Copy'}</span>
                </button>
              </div>
            )}
          </div>

          {/* Source Code Content Container */}
          <div className="flex-1 overflow-auto bg-[#1E1E1E] p-3 font-mono text-xs text-[#CCCCCC] leading-relaxed">
            {isLoadingContent ? (
              <div className="h-full flex items-center justify-center text-xs text-[#858585] italic font-mono">
                Reading file from workspace root...
              </div>
            ) : !selectedFile ? (
              <div className="h-full flex flex-col items-center justify-center text-[#777777] space-y-2 py-12">
                <Terminal className="h-8 w-8 text-[#555555]" />
                <p className="text-xs">Select any source file in the left explorer to view code.</p>
                <p className="text-[11px] text-[#555555]">
                  Supports C, C++, TypeScript, JavaScript, Dart, Rust, JSON, SQL, YAML, and Markdown.
                </p>
              </div>
            ) : (
              <pre className="whitespace-pre overflow-x-auto text-[#D4D4D4] font-mono text-[12px] leading-5">
                {selectedFile.content.split('\n').map((line, idx) => (
                  <div key={idx} className="flex hover:bg-[#2A2D2E]/50">
                    <span className="w-10 select-none text-right pr-4 text-[#6E7681] text-[11px] font-mono shrink-0">
                      {idx + 1}
                    </span>
                    <span className="flex-1 font-mono">{line || ' '}</span>
                  </div>
                ))}
              </pre>
            )}
          </div>

          {/* Source Viewer Footer Bar */}
          {selectedFile && (
            <div className="px-3 py-1.5 bg-[#181818] border-t border-[#333333] text-[11px] font-mono text-[#858585] flex items-center justify-between">
              <div>
                <span>Size: </span>
                <span className="text-[#CCCCCC]">
                  {selectedFile.sizeBytes > 1024
                    ? `${(selectedFile.sizeBytes / 1024).toFixed(1)} KB`
                    : `${selectedFile.sizeBytes} Bytes`}
                </span>
                {selectedFile.isTruncated && <span className="text-amber-400 ml-2">(Preview Truncated)</span>}
              </div>
              <div>
                <span>Encoding: </span>
                <span className="text-[#CCCCCC]">UTF-8</span>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* GitHub Authentication Modal */}
      {showAuthModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
          <div className="w-full max-w-md rounded-lg border border-[#3C3C3C] bg-[#252526] p-5 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-[#333333] pb-3">
              <div className="flex items-center gap-2">
                <Key className="h-4 w-4 text-[#007ACC]" />
                <h2 className="text-sm font-semibold text-white">GitHub Authentication</h2>
              </div>
              <button
                onClick={() => setShowAuthModal(false)}
                className="text-[#858585] hover:text-white text-xs font-mono"
              >
                ✕
              </button>
            </div>

            {authError && (
              <div className="p-2.5 rounded bg-[#F14C4C]/10 border border-[#F14C4C]/30 text-xs text-[#F14C4C] flex items-center gap-2">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{authError}</span>
              </div>
            )}

            <div className="space-y-3 text-xs">
              <p className="text-[#9D9D9D]">
                Configure your GitHub Personal Access Token (PAT) for <code className="text-[#4EC9B0]">pavan-firmware/EH-Master-Repo</code>.
                Tokens are stored securely in session memory and never logged.
              </p>

              <div>
                <label className="block text-[11px] font-mono text-[#858585] mb-1">Personal Access Token (ghp_...)</label>
                <input
                  type="password"
                  value={tokenInput}
                  onChange={(e) => setTokenInput(e.target.value)}
                  placeholder="ghp_xxxxxxxxxxxxxxxxxxxx"
                  className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-3 py-1.5 font-mono text-white text-xs focus:outline-none focus:border-[#007ACC]"
                />
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="writeAccessCheckbox"
                  checked={writeAccessCheckbox}
                  onChange={(e) => setWriteAccessCheckbox(e.target.checked)}
                  className="rounded border-[#3C3C3C] bg-[#1E1E1E] text-[#007ACC]"
                />
                <label htmlFor="writeAccessCheckbox" className="text-xs text-[#CCCCCC] select-none cursor-pointer">
                  Token has Write / Push Permissions for EH-Master-Repo
                </label>
              </div>

              <div className="p-2.5 rounded bg-[#1E1E1E] border border-[#333333] text-[11px] font-mono text-[#858585] space-y-1">
                <div>Current Auth State: <span className="text-white font-medium">{authStatus?.authState || 'NOT_CONNECTED'}</span></div>
                <div>Access Level: <span className="text-[#4EC9B0]">{authStatus?.accessLevel}</span></div>
              </div>
            </div>

            <div className="flex items-center justify-between pt-2 border-t border-[#333333]">
              {authStatus?.isAuthenticated ? (
                <button
                  onClick={handleClearAuthToken}
                  className="rounded bg-[#F14C4C]/20 text-[#F14C4C] hover:bg-[#F14C4C]/30 px-3 py-1.5 text-xs font-medium transition"
                >
                  Disconnect Token
                </button>
              ) : (
                <div />
              )}

              <div className="flex items-center gap-2">
                <button
                  onClick={() => setShowAuthModal(false)}
                  className="rounded bg-[#2D2D2D] hover:bg-[#383838] px-3 py-1.5 text-xs text-[#CCCCCC] transition"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSaveAuthToken}
                  className="rounded bg-[#0E639C] hover:bg-[#1177BB] px-3 py-1.5 text-xs font-medium text-white transition flex items-center gap-1.5"
                >
                  <ShieldCheck className="h-3.5 w-3.5" />
                  <span>Save & Authenticate</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
