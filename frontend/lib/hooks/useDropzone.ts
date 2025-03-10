import { FileRejection, useDropzone } from "react-dropzone";
import { useTranslation } from "react-i18next";

import { FeedItemUploadType } from "@/app/chat/[chatId]/components/ActionsBar/types";
import { useEventTracking } from "@/services/analytics/june/useEventTracking";


import { useToast } from "./useToast";
import { useKnowledgeToFeedContext } from "../context/KnowledgeToFeedProvider/hooks/useKnowledgeToFeedContext";
import { acceptedFormats } from "../helpers/acceptedFormats";

// eslint-disable-next-line @typescript-eslint/explicit-module-boundary-types
export const useCustomDropzone = () => {
  const { knowledgeToFeed, addKnowledgeToFeed } = useKnowledgeToFeedContext();

  const files: File[] = (
    knowledgeToFeed.filter((c) => c.source === "upload") as FeedItemUploadType[]
  ).map((c) => c.file);

  const { publish } = useToast();
  const { track } = useEventTracking();

  const { t } = useTranslation(["upload"]);

  const onDrop = (acceptedFiles: File[], fileRejections: FileRejection[]) => {
    if (fileRejections.length > 0) {
      const firstRejection = fileRejections[0];

      if (firstRejection.errors[0].code === "file-invalid-type") {
        publish({ variant: "danger", text: t("invalidFileType") });
      } else {
        publish({
          variant: "danger",
          text: t("maxSizeError", { ns: "upload" }),
        });
      }

      return;
    }

    for (const file of acceptedFiles) {
      const isAlreadyInFiles =
        files.filter((f) => f.name === file.name && f.size === file.size)
          .length > 0;
      if (isAlreadyInFiles) {
        publish({
          variant: "warning",
          text: t("alreadyAdded", { fileName: file.name, ns: "upload" }),
        });
      } else {
        void track("FILE_UPLOADED");
        addKnowledgeToFeed({
          source: "upload",
          file: file,
        });
      }
    }
  };

  const { getInputProps, getRootProps, isDragActive, open } = useDropzone({
    onDrop,
    noClick: true,
    maxSize: 100000000, // 1 MB
    accept: acceptedFormats,
  });

  return {
    getInputProps,
    getRootProps,
    isDragActive,
    open,
  };
};
